import { AptosClient } from "aptos";

export const client = new AptosClient(
  "https://fullnode.devnet.aptoslabs.com/v1"
);

export const MODULE_ADDR  = import.meta.env.VITE_MODULE_ADDR;
export const REGISTER_FN  = `${MODULE_ADDR}::skillshare::register_user_with_contact`;
export const ADD_SKILL_FN = `${MODULE_ADDR}::skillshare::add_skill`;
export const USER_STRUCT  = `${MODULE_ADDR}::skillshare::User`;
export const REQUEST_FN = `${MODULE_ADDR}::skillshare::request_teach`;
export const ACCEPT_FN  = `${MODULE_ADDR}::skillshare::accept_request`;

// ==================== FIXED CACHING SYSTEM ====================

const cache = new Map();
const CACHE_TTL = 30000; // 30 seconds

// Update the memo function to handle network errors
function memo(key, ttlMs, getter) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.timestamp < ttlMs) {
    return Promise.resolve(hit.value);
  }
  
  if (hit && Date.now() - hit.timestamp >= ttlMs) {
    cache.delete(key);
  }
  
  const promise = getter().then(value => {
    cache.set(key, { value, timestamp: Date.now() });
    return value;
  }).catch(error => {
    console.error(`Cache miss for ${key}:`, error.message);
    
    // For network errors, return cached value if available
    if (error.code === 'ERR_NETWORK' && hit) {
      console.log(`Using stale cache for ${key} due to network error`);
      return hit.value;
    }
    
    cache.delete(key);
    throw error;
  });
  
  return promise;
}



export const encode = (str) =>
  Array.from(new TextEncoder().encode(str));

export const decode = (value) => {
  if (typeof value === "string" && value.startsWith("0x")) {
    const bytes = [];
    for (let i = 2; i < value.length; i += 2) {
      bytes.push(parseInt(value.slice(i, i + 2), 16));
    }
    return new TextDecoder().decode(new Uint8Array(bytes));
  }
  if (Array.isArray(value)) {
    return new TextDecoder().decode(new Uint8Array(value));
  }
  return value;
};

export const buildPayload = (entryFn, args = []) => ({
  data: {
    function: entryFn,
    type_arguments: [],
    functionArguments: args,
  },
});

// Simple, direct address conversion
export const getAccountAddress = (account) => {
  if (!account || !account.address) return null;
  
  // Try toString() first (for AccountAddress objects)
  if (typeof account.address.toString === "function") {
    return account.address.toString();
  }
  
  // If it's already a string
  if (typeof account.address === "string") {
    return account.address;
  }
  
  return null;
};

/* ----------  view helpers ---------- */

/** true if any User resource exists at addr */
export const userExists = addr =>
  memo(`ue_${addr}`, 60_000, () =>
    client.view({
      function: `${MODULE_ADDR}::skillshare::user_exists`,
      type_arguments: [],
      arguments: [addr],
    }).then(([flag]) => flag)
  );

/** { name:string, skills:string[] }  or null */
export const fetchProfile = addr =>
  memo(`prof_${addr}`, 60_000, async () => {
    if (!(await userExists(addr))) return null;
    const r = await client.getAccountResource(addr, USER_STRUCT);
    return {
      name: decode(r.data.name),
      skills: r.data.skills.map(decode),
      contact_info: decode(r.data.contact_info),
    };
  });

const queue = [];
let running = 0;
function queued(fn) {
  return new Promise((res, rej) => {
    queue.push([fn, res, rej]); pump();
  });
}
function pump() {
  if (!queue.length || running) return;
  running = 1;
  const [fn, res, rej] = queue.shift();
  fn().then(res).catch(rej).finally(() => {
    running = 0;
    setTimeout(pump, 300);  // 300ms delay
  });
}

// Send a teach request (learner → teacher)
export async function sendTeachRequest({ teacher, skill, signAndSubmitTransaction }) {
  const payload = buildPayload(REQUEST_FN, [teacher, encode(skill)]);
  return await signAndSubmitTransaction(payload);
}

// Accept a teach request (teacher)
export async function acceptTeachRequest({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(ACCEPT_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

// TODO: Replace this with real data or indexer in the future
export async function fetchAllTeachers() {
  const registered = await fetchAllRegisteredAddresses();
  const teachers = [];
  for (const { address, name} of registered) {
    try {
      const resource = await client.getAccountResource(address, USER_STRUCT);
      const skills = resource.data.skills.map(decode);
      if (skills.length > 0) {
        teachers.push({
          address,
          name,
          skills
        });
      }
    } catch (e) {
      continue;
    }
  }
  return teachers;
}


export async function fetchTeacherRequests(teacherAddr) {
  const cacheKey = `teacher_requests_${teacherAddr}`;
  
  return memo(cacheKey, 15000, async () => {
    // Get all events at once to reduce API calls
    const [requestEvents, acceptEvents, rejectEvents] = await Promise.all([
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "request_events"),
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "accept_events"),
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "rejected_events")
    ]);
    
    const acceptedIds = new Set(acceptEvents.map(e => e.data.id));
    const rejectedIds = new Set(rejectEvents.map(e => e.data.id));

    return requestEvents
      .filter(e => e.data.teacher.toLowerCase() === teacherAddr.toLowerCase())
      .map(e => ({
        id: e.data.id,
        learner: e.data.learner,
        skill: decode(e.data.skill),
        accepted: acceptedIds.has(e.data.id),
        rejected: rejectedIds.has(e.data.id)
      }));
  });
}

/** Fetch learner requests with caching */
export async function fetchLearnerRequests(learnerAddr) {
  const cacheKey = `learner_requests_${learnerAddr}`;
  
  return memo(cacheKey, 15000, async () => {
    // Get all events at once to reduce API calls
    const [requestEvents, acceptEvents, rejectEvents] = await Promise.all([
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "request_events"),
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "accept_events"),
      client.getEventsByEventHandle(MODULE_ADDR, `${MODULE_ADDR}::skillshare::GlobalRequests`, "rejected_events")
    ]);
    
    const acceptedIds = new Set(acceptEvents.map(e => e.data.id));
    const rejectedIds = new Set(rejectEvents.map(e => e.data.id));

    return requestEvents
      .filter(e => e.data.learner.toLowerCase() === learnerAddr.toLowerCase())
      .map(e => ({
        id: e.data.id,
        teacher: e.data.teacher,
        skill: decode(e.data.skill),
        accepted: acceptedIds.has(e.data.id),
        rejected: rejectedIds.has(e.data.id)
      }));
  });
}

/** Fetch all registered addresses with caching */
export async function fetchAllRegisteredAddresses() {
  const cacheKey = 'all_registered_addresses';
  
  return memo(cacheKey, 30000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::RegistrationEvents`,
        "handle"
      );
      
      return events.map(e => ({
        address: e.data.addr,
        name: decode(e.data.name),
      }));
    } catch (error) {
      console.error("Error fetching registered addresses:", error);
      return [];
    }
  });
}
// Add this temporary function to debug
export async function debugGlobalRequests() {
  try {
    const globalRes = await client.getAccountResource(
      MODULE_ADDR,
      `${MODULE_ADDR}::skillshare::GlobalRequests`
    );
    console.log("GlobalRequests resource:", globalRes);
    console.log("request_events structure:", globalRes.data.request_events);
    return globalRes;
  } catch (error) {
    console.error("Error fetching GlobalRequests:", error);
    return null;
  }
}

// Add this function for on-chain rejection
export async function rejectTeachRequest({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(
    `${MODULE_ADDR}::skillshare::reject_request`,
    [requestId]
  );
  return await signAndSubmitTransaction(payload);
}

// Add this new helper function
export const registerUserWithContact = async ({ name, contactInfo, signAndSubmitTransaction }) => {
  const payload = buildPayload(REGISTER_FN, [
    encode(name),
    encode(contactInfo)
  ]);
  return await signAndSubmitTransaction(payload);
};



window.debugGlobalRequests = debugGlobalRequests;

// ==================== WEEK 3 PAYMENT & COMMUNICATION FUNCTIONS ====================

// Payment System Functions
export const DEPOSIT_PAYMENT_FN = `${MODULE_ADDR}::skillshare::deposit_payment`;
export const ACKNOWLEDGE_PAYMENT_FN = `${MODULE_ADDR}::skillshare::acknowledge_payment`;
export const TEACHER_REQUEST_RELEASE_FN = `${MODULE_ADDR}::skillshare::teacher_request_release`;
export const LEARNER_CONFIRM_COMPLETION_FN = `${MODULE_ADDR}::skillshare::learner_confirm_completion`;

// Communication Functions
export const MARK_COMMUNICATION_FN = `${MODULE_ADDR}::skillshare::learner_mark_communication_started`;
export const REPORT_NON_RESPONSE_FN = `${MODULE_ADDR}::skillshare::learner_report_non_response`;
export const CLAIM_REFUND_FN = `${MODULE_ADDR}::skillshare::claim_refund`;

// View Functions
export const GET_CONTACT_INFO_FN = `${MODULE_ADDR}::skillshare::get_contact_info`;

// Constants
export const LESSON_PRICE = 100000000; // 1 APT in octas
export const RESPONSE_WINDOW = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// ==================== WEEK 3 PAYMENT FUNCTIONS ====================

/** Deposit 1 APT payment for accepted request */
export async function depositPayment({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(DEPOSIT_PAYMENT_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

/** Teacher acknowledges payment and gains access to contact info */
export async function acknowledgePayment({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(ACKNOWLEDGE_PAYMENT_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

/** Teacher requests payment release after lesson completion */
export async function teacherRequestRelease({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(TEACHER_REQUEST_RELEASE_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

/** Learner confirms completion and releases payment to teacher */
export async function learnerConfirmCompletion({ requestId, signAndSubmitTransaction }) {
  // Note: This function requires admin signer for escrow release
  // For now, we'll call it with the learner signer
  // TODO: Implement proper two-signer mechanism
  const payload = buildPayload(LEARNER_CONFIRM_COMPLETION_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

// ==================== WEEK 3 COMMUNICATION FUNCTIONS ====================

/** Learner marks that teacher has made contact */
export async function markCommunicationStarted({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(MARK_COMMUNICATION_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

/** Learner reports teacher non-response (after 24 hours) */
export async function reportNonResponse({ requestId, signAndSubmitTransaction }) {
  const payload = buildPayload(REPORT_NON_RESPONSE_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

/** Learner claims refund for non-responsive teacher */
export async function claimRefund({ requestId, signAndSubmitTransaction }) {
  // Note: This function requires admin signer for escrow release
  // For now, we'll call it with the learner signer
  // TODO: Implement proper two-signer mechanism
  const payload = buildPayload(CLAIM_REFUND_FN, [requestId]);
  return await signAndSubmitTransaction(payload);
}

// ==================== WEEK 3 VIEW FUNCTIONS ====================

/** Get contact information for a request (only accessible after payment acknowledgment) */
export async function getContactInfo(requestId, requesterAddress) {
  try {
    const [contactInfo] = await client.view({
      function: GET_CONTACT_INFO_FN,
      type_arguments: [],
      arguments: [requestId, requesterAddress],
    });
    return decode(contactInfo);
  } catch (error) {
    console.error("Error fetching contact info:", error);
    throw new Error("Contact info not available or not authorized");
  }
}

/** Get user's APT balance */
/** Get user's APT balance with registration check */
// export async function getUserBalance(address) {
//   return memo(`balance_${address}`, 10_000, async () => {
//     try {
//       const resources = await client.getAccountResources(address);
//       const coinStoreResource = resources.find(r => 
//         r.type === "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"
//       );
      
//       if (coinStoreResource) {
//         return parseInt(coinStoreResource.data.coin.value);
//       } else {
//         return null; // Not registered
//       }
//     } catch (error) {
//       console.error("Error fetching balance:", error);
//       return null;
//     }
//   });
// }


// ==================== BALANCE & REGISTRATION FUNCTIONS ====================

/** Get user's APT balance */
export async function getUserBalance(address) {
  const cacheKey = `balance_${address}`;
  
  return memo(cacheKey, 10000, async () => {
    try {
      const resources = await client.getAccountResources(address);
      const coinStoreResource = resources.find(r => 
        r.type === "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"
      );
      
      if (coinStoreResource) {
        return parseInt(coinStoreResource.data.coin.value);
      } else {
        return null; // Not registered
      }
    } catch (error) {
      console.error("Error fetching balance:", error);
      return null;
    }
  });
}




// ==================== WEEK 3 EVENT FUNCTIONS WITH CACHING ====================

/** Fetch payment events for a request */
export async function fetchPaymentEvents(requestId) {
  const cacheKey = `payment_events_${requestId}`;
  
  return memo(cacheKey, 15000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "payment_events"
      );
      return events.filter(e => e.data.request_id === String(requestId));
    } catch (error) {
      console.error("Error fetching payment events:", error);
      return [];
    }
  });
}

/** Fetch acknowledgment events for a request */
export async function fetchAcknowledgmentEvents(requestId) {
  const cacheKey = `ack_events_${requestId}`;
  
  return memo(cacheKey, 15000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "acknowledgment_events"
      );
      return events.filter(e => e.data.request_id === String(requestId));
    } catch (error) {
      console.error("Error fetching acknowledgment events:", error);
      return [];
    }
  });
}

/** Fetch communication events for a request */
export async function fetchCommunicationEvents(requestId) {
  const cacheKey = `comm_events_${requestId}`;
  
  return memo(cacheKey, 15000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "communication_events"
      );
      return events.filter(e => e.data.request_id === String(requestId));
    } catch (error) {
      console.error("Error fetching communication events:", error);
      return [];
    }
  });
}

/** Fetch release events for a request */
export async function fetchReleaseEvents(requestId) {
  const cacheKey = `release_events_${requestId}`;
  
  return memo(cacheKey, 15000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "release_events"
      );
      return events.filter(e => e.data.request_id === String(requestId));
    } catch (error) {
      console.error("Error fetching release events:", error);
      return [];
    }
  });
}

/** Fetch refund events for a request */
export async function fetchRefundEvents(requestId) {
  const cacheKey = `refund_events_${requestId}`;
  
  return memo(cacheKey, 15000, async () => {
    try {
      const events = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "refund_events"
      );
      return events.filter(e => e.data.request_id === String(requestId));
    } catch (error) {
      console.error("Error fetching refund events:", error);
      return [];
    }
  });
}

/** Get complete request status including payment and communication state */
export async function getEnhancedRequestStatus(requestId) {
  return queued(async () => {
    try {
      // Get basic request info
      const requestEvents = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "request_events"
      );
      
      const acceptEvents = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "accept_events"
      );
      
      const rejectEvents = await client.getEventsByEventHandle(
        MODULE_ADDR,
        `${MODULE_ADDR}::skillshare::GlobalRequests`,
        "rejected_events"
      );

      // Get payment and communication events
      const paymentEvents = await fetchPaymentEvents(requestId);
      const ackEvents = await fetchAcknowledgmentEvents(requestId);
      const commEvents = await fetchCommunicationEvents(requestId);
      const releaseEvents = await fetchReleaseEvents(requestId);
      const refundEvents = await fetchRefundEvents(requestId);

      // Find the request
      const request = requestEvents.find(e => e.data.id === String(requestId));
      if (!request) {
        throw new Error("Request not found");
      }

      // Build enhanced status
      const isAccepted = acceptEvents.some(e => e.data.id === String(requestId));
      const isRejected = rejectEvents.some(e => e.data.id === String(requestId));
      const isPaymentDeposited = paymentEvents.length > 0;
      const isAcknowledged = ackEvents.length > 0;
      const isCommunicationStarted = commEvents.length > 0;
      const isReleaseRequested = releaseEvents.length > 0;
      const isCompleted = releaseEvents.length > 0;
      const isRefunded = refundEvents.length > 0;

      return {
        id: request.data.id,
        learner: request.data.learner,
        teacher: request.data.teacher,
        skill: decode(request.data.skill),
        accepted: isAccepted,
        rejected: isRejected,
        paymentDeposited: isPaymentDeposited,
        acknowledged: isAcknowledged,
        communicationStarted: isCommunicationStarted,
        releaseRequested: isReleaseRequested,
        completed: isCompleted,
        refunded: isRefunded,
        paymentTime: paymentEvents[0]?.data?.timestamp,
        acknowledgmentTime: ackEvents[0]?.data?.timestamp,
        communicationTime: commEvents[0]?.data?.timestamp,
      };
    } catch (error) {
      console.error("Error fetching enhanced request status:", error);
      throw error;
    }
  });
}


export async function registerUserForCoin({ signAndSubmitTransaction }) {
  try {
    const payload = buildPayload(
      `${MODULE_ADDR}::skillshare::register_for_aptos_coin`,
      []
    );
    
    console.log("Sending registration payload:", payload);
    
    const result = await signAndSubmitTransaction(payload);
    
    // ✅ Log the complete transaction result
    console.log("Registration transaction result:", result);
    console.log("Transaction hash:", result?.hash);
    
    return result;
  } catch (error) {
    console.error("Registration transaction failed:", error);
    throw error;
  }
}


/** Check if user is registered for AptosCoin with enhanced debugging */
export async function isUserRegisteredForCoin(address) {
  const cacheKey = `coin_registered_${address}`;
  
  return memo(cacheKey, 30000, async () => {
    try {
      console.log(`🔍 Checking coin registration for: ${address.slice(0, 8)}...`);
      
      const resources = await client.getAccountResources(address);
      console.log(`📋 Found ${resources.length} resources for address`);
      
      // Debug: Log all resource types
      resources.forEach((resource, index) => {
        console.log(`Resource ${index + 1}:`, resource.type);
      });
      
      // Check for AptosCoin CoinStore with multiple possible formats
      const coinStoreVariations = [
        "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
        "0x00000000000000000000000000000001::coin::CoinStore<0x00000000000000000000000000000001::aptos_coin::AptosCoin>",
        "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
      ];
      
      const coinStore = resources.find(r => 
        coinStoreVariations.some(variation => r.type === variation) ||
        r.type.includes("coin::CoinStore") && r.type.includes("aptos_coin::AptosCoin")
      );
      
      const isRegistered = !!coinStore;
      
      console.log(`💰 CoinStore found:`, isRegistered);
      if (coinStore) {
        console.log(`💰 CoinStore type:`, coinStore.type);
        console.log(`💰 CoinStore data:`, coinStore.data);
      }
      
      return isRegistered;
    } catch (error) {
      console.error("❌ Error checking coin registration:", error);
      return false;
    }
  });
}


// ==================== TESTING HELPER ====================

/** Test Week 3 functions with real user data */
export async function testWeek3Functions() {
  console.log("Testing Week 3 functions...");
  
  try {
    // Test with the learner's address from the enhanced status
    const status = await getEnhancedRequestStatus(1);
    console.log("Enhanced request status:", status);
    
    // Test balance fetching with learner's address
    if (status.learner) {
      const learnerBalance = await getUserBalance(status.learner);
      console.log("Learner balance:", learnerBalance);
    }
    
    // Test balance fetching with teacher's address
    if (status.teacher) {
      const teacherBalance = await getUserBalance(status.teacher);
      console.log("Teacher balance:", teacherBalance);
    }
    
    return true;
  } catch (error) {
    console.error("Week 3 function test failed:", error);
    return false;
  }
}


/** Check if contract is registered for AptosCoin */
export async function checkContractCoinRegistration() {
  try {
    const resources = await client.getAccountResources(MODULE_ADDR);
    const hasCoinStore = resources.some(r => 
      r.type === "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"
    );
    
    console.log(`Contract CoinStore registration: ${hasCoinStore}`);
    return hasCoinStore;
  } catch (error) {
    console.error("Error checking contract registration:", error);
    return false;
  }
}


// Make it available in browser console
if (typeof window !== 'undefined') {
  window.testWeek3Functions = testWeek3Functions;
}


// ==================== CACHE MANAGEMENT ====================

/** Clear cache for specific user data */
export function clearUserCache(address) {
  cache.delete(`coin_registered_${address}`);
  cache.delete(`balance_${address}`);
  cache.delete(`ue_${address}`);
  cache.delete(`prof_${address}`);
  console.log(`Cleared cache for address: ${address.slice(0, 8)}...`);
}

/** Clear all cache (for debugging) */
export function clearAllCache() {
  cache.clear();
  console.log("All cache cleared");
}

// Make available in browser console for debugging
if (typeof window !== 'undefined') {
  window.clearUserCache = clearUserCache;
  window.clearAllCache = clearAllCache;
}

// Add to Aptos.js for debugging
let apiCallCount = 0;
const originalClientView = client.view;
const originalGetEventsByEventHandle = client.getEventsByEventHandle;

client.view = function(...args) {
  apiCallCount++;
  console.log(`API Call #${apiCallCount}: view`, args[0]?.function);
  return originalClientView.apply(this, args);
};

client.getEventsByEventHandle = function(...args) {
  apiCallCount++;
  console.log(`API Call #${apiCallCount}: events`, args[2]);
  return originalGetEventsByEventHandle.apply(this, args);
};

// Reset counter function
window.resetApiCount = () => { apiCallCount = 0; };


export async function checkNetworkStatus() {
  try {
    await client.getLedgerInfo();
    return true;
  } catch (error) {
    console.error("Network connectivity issue:", error);
    return false;
  }
}


// In Aptos.js - add debugging function
export async function debugAccountResources(address) {
  try {
    const resources = await client.getAccountResources(address);
    console.log("All account resources:", resources);
    
    const coinStore = resources.find(r => 
      r.type === "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"
    );
    
    console.log("AptosCoin CoinStore:", coinStore);
    
    return {
      hasResources: resources.length > 0,
      hasCoinStore: !!coinStore,
      coinStoreData: coinStore?.data
    };
  } catch (error) {
    console.error("Error checking account resources:", error);
    return { hasResources: false, hasCoinStore: false, error: error.message };
  }
}

// Make available in console
if (typeof window !== 'undefined') {
  window.debugAccountResources = debugAccountResources;
}
