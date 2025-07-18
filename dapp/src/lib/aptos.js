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
export const userExists = async (addr) => {
  const [flag] = await client.view({
    function: `${MODULE_ADDR}::skillshare::user_exists`,
    type_arguments: [],
    arguments: [addr],
  });
  return flag;                        // boolean
};

/** { name:string, skills:string[] }  or null */
export const fetchProfile = async (addr) => {
  if (!(await userExists(addr))) return null;

  const resource = await client.getAccountResource(addr, USER_STRUCT);
  return {
    name:   decode(resource.data.name),
    skills: resource.data.skills.map(decode),
    contact_info: decode(resource.data.contact_info),
  };
};

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
  const globalRes = await client.getAccountResource(
    MODULE_ADDR,
    `${MODULE_ADDR}::skillshare::GlobalRequests`
  );
  // Fetch all request events
  const requestEvents = await client.getEventsByEventHandle(
    MODULE_ADDR,
    `${MODULE_ADDR}::skillshare::GlobalRequests`,
    "request_events"
  );
  // Fetch all accept events
  const acceptEvents = await client.getEventsByEventHandle(
    MODULE_ADDR,
    `${MODULE_ADDR}::skillshare::GlobalRequests`,
    "accept_events"
  );
  // Fetch all reject events
  const rejectEvents = await client.getEventsByEventHandle(
    MODULE_ADDR,
    `${MODULE_ADDR}::skillshare::GlobalRequests`,
    "rejected_events"
  );
  const acceptedIds = new Set(acceptEvents.map(e => e.data.id));
  const rejectedIds = new Set(rejectEvents.map(e => e.data.id));

  // Only show pending or accepted
  return requestEvents
    .filter(e => e.data.teacher.toLowerCase() === teacherAddr.toLowerCase())
    .map(e => ({
      id: e.data.id,
      learner: e.data.learner,
      skill: decode(e.data.skill),
      accepted: acceptedIds.has(e.data.id),
      rejected: rejectedIds.has(e.data.id)
    }));
}


export async function fetchLearnerRequests(learnerAddr) {
  const globalRes = await client.getAccountResource(
    MODULE_ADDR,
    `${MODULE_ADDR}::skillshare::GlobalRequests`
  );
  // Fetch events
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
}


export async function fetchAllRegisteredAddresses() {
  try {
    // Direct event handle approach
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