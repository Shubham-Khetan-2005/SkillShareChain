import { useState, useEffect } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { 
  fetchLearnerRequests, 
  fetchProfile, 
  getAccountAddress,
  getEnhancedRequestStatus,
  depositPayment,
  markCommunicationStarted,
  reportNonResponse,
  claimRefund,
  getUserBalance,
  registerUserForCoin,
  isUserRegisteredForCoin,
  clearUserCache,
  LESSON_PRICE 
} from "../lib/aptos";
import { toast } from "react-hot-toast";

export default function LessonTab() {
  const { account, signAndSubmitTransaction } = useWallet();
  const [acceptedLessons, setAcceptedLessons] = useState([]);
  const [teacherNames, setTeacherNames] = useState({});
  const [lessonStatuses, setLessonStatuses] = useState({});
  const [userBalance, setUserBalance] = useState(0);
  const [isRegisteredForCoin, setIsRegisteredForCoin] = useState(false);
  const [loading, setLoading] = useState(true);
  const [registering, setRegistering] = useState(false);
  const [lastCheckedIds, setLastCheckedIds] = useState(new Set());
  const [rateLimitError, setRateLimitError] = useState(false);

  // Load accepted lessons with rate limiting protection
  useEffect(() => {
    let mounted = true;
    let intervalId;

    const loadAcceptedLessons = async () => {
      if (!account || !mounted) {
        setAcceptedLessons([]);
        setLoading(false);
        return;
      }

      try {
        setRateLimitError(false);
        const learnerAddr = getAccountAddress(account);
        
        // Check registration status
        const registered = await isUserRegisteredForCoin(learnerAddr);
        if (mounted) setIsRegisteredForCoin(registered);

        // Get balance if registered
        if (registered && mounted) {
          const balance = await getUserBalance(learnerAddr);
          setUserBalance(balance);
        } else if (mounted) {
          setUserBalance(null);
        }

        // Get requests with delay to prevent rate limiting
        await new Promise(resolve => setTimeout(resolve, 200));
        const allRequests = await fetchLearnerRequests(learnerAddr);
        
        if (!mounted) return;
        
        const accepted = allRequests.filter(req => req.accepted && !req.rejected);
        
        // Check for new acceptances
        const newAcceptedIds = new Set(accepted.map(req => req.id));
        const newlyAccepted = accepted.filter(req => !lastCheckedIds.has(req.id));
        
        // Show toast for newly accepted lessons
        newlyAccepted.forEach(lesson => {
          toast.success(`🎉 Your lesson request for "${lesson.skill}" has been accepted!`, {
            duration: 5000,
            position: 'top-center',
          });
        });
        
        if (mounted) {
          setLastCheckedIds(newAcceptedIds);
          setAcceptedLessons(accepted);
        }

        // Process teacher names and statuses with rate limiting
        const teacherMap = {};
        const statusMap = {};
        
        for (const lesson of accepted) {
          if (!mounted) break;
          
          try {
            // Add delay between requests to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 300));
            
            const profile = await fetchProfile(lesson.teacher);
            teacherMap[lesson.teacher] = profile?.name || lesson.teacher.slice(0, 8) + "...";
            
            // Add another delay
            await new Promise(resolve => setTimeout(resolve, 300));
            
            const status = await getEnhancedRequestStatus(lesson.id);
            statusMap[lesson.id] = status;
          } catch (error) {
            console.error(`Failed to get data for lesson ${lesson.id}:`, error);
            if (error.message?.includes("rate limit") || error.message?.includes("429")) {
              console.warn("Rate limit hit, stopping further requests");
              if (mounted) setRateLimitError(true);
              break;
            }
            statusMap[lesson.id] = { ...lesson, paymentDeposited: false, acknowledged: false };
          }
        }
        
        if (mounted) {
          setTeacherNames(teacherMap);
          setLessonStatuses(statusMap);
        }
      } catch (error) {
        console.error("Error loading accepted lessons:", error);
        if (mounted && (error.message?.includes("rate limit") || error.message?.includes("429"))) {
          setRateLimitError(true);
          toast.error("Rate limit exceeded. Please wait a moment and refresh.");
        }
      } finally {
        if (mounted) setLoading(false);
      }
    };

    // Initial load
    loadAcceptedLessons();
    
    // Set up periodic refresh with longer interval
    const startPolling = () => {
      intervalId = setInterval(() => {
        if (mounted && document.visibilityState === 'visible') {
          loadAcceptedLessons();
        }
      }, 90000); // 90 seconds interval to avoid rate limits
    };

    // Start polling after initial load
    setTimeout(startPolling, 15000); // Wait 15 seconds before starting polling

    return () => {
      mounted = false;
      if (intervalId) clearInterval(intervalId);
    };
  }, [account]);

  // Manual refresh function
  const handleManualRefresh = async () => {
    if (!account) return;
    
    setLoading(true);
    const learnerAddr = getAccountAddress(account);
    
    // Clear cache for this user
    clearUserCache(learnerAddr);
    
    // Wait a moment then reload
    await new Promise(resolve => setTimeout(resolve, 1000));
    window.location.reload();
  };

  // Registration handler
  const handleRegisterForCoin = async () => {
    if (!account) {
      toast.error("Please connect your wallet first");
      return;
    }

    setRegistering(true);
    try {
      await registerUserForCoin({ signAndSubmitTransaction });
      toast.success("Wallet registered for APT!");
      
      // Force refresh of registration status and balance
      const learnerAddr = getAccountAddress(account);
      
      // Wait for blockchain state to update
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Clear cache for this user's registration and balance
      clearUserCache(learnerAddr);
      
      // Refresh registration status
      const registered = await isUserRegisteredForCoin(learnerAddr);
      setIsRegisteredForCoin(registered);
      
      // Refresh balance if registered
      if (registered) {
        const balance = await getUserBalance(learnerAddr);
        setUserBalance(balance);
        toast.success(`Balance updated: ${balance ? balance / 100000000 : 0} APT`);
      }
      
    } catch (error) {
      console.error("Registration failed:", error);
      toast.error("Registration failed: " + (error?.message || "Unknown error"));
    } finally {
      setRegistering(false);
    }
  };

  // Payment handler
  const handlePayment = async (lessonId) => {
    if (!isRegisteredForCoin) {
      toast.error("Please register for AptosCoin first to hold APT tokens.");
      return;
    }

    if (userBalance === null || userBalance < LESSON_PRICE) {
      toast.error(`Insufficient balance. You need ${LESSON_PRICE / 100000000} APT to pay for this lesson.`);
      return;
    }

    try {
      await depositPayment({
        requestId: lessonId,
        signAndSubmitTransaction,
      });
      
      toast.success("Payment deposited successfully! Teacher will be notified.");
      
      // Refresh lesson status and balance
      await new Promise(resolve => setTimeout(resolve, 2000));
      const status = await getEnhancedRequestStatus(lessonId);
      setLessonStatuses(prev => ({ ...prev, [lessonId]: status }));
      
      const learnerAddr = getAccountAddress(account);
      const newBalance = await getUserBalance(learnerAddr);
      setUserBalance(newBalance);
    } catch (error) {
      console.error("Payment failed:", error);
      toast.error("Payment failed: " + (error?.message || "Unknown error"));
    }
  };

  // Communication started handler
  const handleCommunicationStarted = async (lessonId) => {
    try {
      await markCommunicationStarted({
        requestId: lessonId,
        signAndSubmitTransaction,
      });
      
      toast.success("Communication marked as started!");
      
      // Refresh lesson status
      const status = await getEnhancedRequestStatus(lessonId);
      setLessonStatuses(prev => ({ ...prev, [lessonId]: status }));
    } catch (error) {
      console.error("Failed to mark communication:", error);
      toast.error("Failed to mark communication: " + (error?.message || "Unknown error"));
    }
  };

  // Non-response handler
  const handleNonResponse = async (lessonId) => {
    try {
      await reportNonResponse({
        requestId: lessonId,
        signAndSubmitTransaction,
      });
      
      toast.success("Non-response reported. You can now claim a refund.");
      
      // Refresh lesson status
      const status = await getEnhancedRequestStatus(lessonId);
      setLessonStatuses(prev => ({ ...prev, [lessonId]: status }));
    } catch (error) {
      console.error("Failed to report non-response:", error);
      toast.error("Failed to report non-response: " + (error?.message || "Unknown error"));
    }
  };

  // Refund handler
  const handleRefund = async (lessonId) => {
    try {
      await claimRefund({
        requestId: lessonId,
        signAndSubmitTransaction,
      });
      
      toast.success("Refund claimed successfully!");
      
      // Refresh lesson status and balance
      const status = await getEnhancedRequestStatus(lessonId);
      setLessonStatuses(prev => ({ ...prev, [lessonId]: status }));
      
      const learnerAddr = getAccountAddress(account);
      const newBalance = await getUserBalance(learnerAddr);
      setUserBalance(newBalance);
    } catch (error) {
      console.error("Failed to claim refund:", error);
      toast.error("Failed to claim refund: " + (error?.message || "Unknown error"));
    }
  };

  // Calculate time since payment for 24-hour check
  const getHoursSincePayment = (paymentTime) => {
    if (!paymentTime) return 0;
    const now = Date.now();
    const paymentDate = new Date(paymentTime * 1000);
    return Math.floor((now - paymentDate) / (1000 * 60 * 60));
  };

  if (loading) {
    return (
      <div className="card p-6">
        <h2 className="text-xl font-bold mb-4">My Lessons</h2>
        <div className="text-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading lessons...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="card p-6">
      {/* Header with refresh button */}
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-bold">My Lessons</h2>
        <div className="flex items-center gap-4">
          <button
            onClick={handleManualRefresh}
            className="text-sm bg-gray-100 hover:bg-gray-200 px-3 py-1 rounded-md"
            disabled={loading}
          >
            🔄 Refresh
          </button>
          <div className="text-sm text-gray-600">
            {isRegisteredForCoin ? (
              <>Balance: <span className="font-semibold">{userBalance ? userBalance / 100000000 : 0} APT</span></>
            ) : (
              <span className="text-red-600">Not registered for APT</span>
            )}
          </div>
        </div>
      </div>

      {/* Rate Limit Warning */}
      {rateLimitError && (
        <div className="mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
          <p className="text-yellow-800 text-sm">
            ⚠️ Rate limit exceeded. Some data may not be up to date. Please wait a moment and use the refresh button.
          </p>
        </div>
      )}

      {/* Coin Registration Section */}
      {!isRegisteredForCoin && (
        <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-md">
          <h3 className="font-medium text-blue-900 mb-2">Register for AptosCoin</h3>
          <p className="text-blue-800 text-sm mb-3">
            You need to register your wallet to hold APT tokens before you can make payments.
          </p>
          <button
            onClick={handleRegisterForCoin}
            disabled={registering}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {registering ? "Registering..." : "Register for Aptos Coin"}
          </button>
        </div>
      )}

      {/* Lessons Display */}
      {acceptedLessons.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-gray-400 mb-4">
            <svg className="mx-auto h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
          </div>
          <h3 className="text-lg font-medium text-gray-900 mb-2">No lessons yet</h3>
          <p className="text-gray-600">
            Once a teacher accepts your request, your lessons will appear here.
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {acceptedLessons.map(lesson => {
            const status = lessonStatuses[lesson.id] || lesson;
            const hoursSincePayment = getHoursSincePayment(status.paymentTime);
            const canReportNonResponse = status.paymentDeposited && status.acknowledged && 
                                       !status.communicationStarted && hoursSincePayment >= 24;

            return (
              <div key={lesson.id} className="border rounded-lg p-6 bg-white shadow-sm">
                {/* Lesson Header */}
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h3 className="text-lg font-semibold text-gray-900">{lesson.skill}</h3>
                    <p className="text-gray-600">
                      with <span className="font-medium">{teacherNames[lesson.teacher] || "Loading..."}</span>
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                    Accepted
                  </span>
                </div>

                {/* Progress Steps */}
                <div className="mb-6">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Progress</span>
                    <span className="text-sm text-gray-500">
                      {status.completed ? "Completed" : 
                       status.refunded ? "Refunded" : 
                       status.communicationStarted ? "In Progress" :
                       status.acknowledged ? "Waiting for Contact" :
                       status.paymentDeposited ? "Payment Acknowledged" : "Payment Required"}
                    </span>
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    {/* Step indicators */}
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
                      status.paymentDeposited ? "bg-green-500 text-white" : "bg-gray-200 text-gray-600"
                    }`}>1</div>
                    <div className={`flex-1 h-2 rounded ${status.acknowledged ? "bg-green-500" : "bg-gray-200"}`}></div>
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
                      status.acknowledged ? "bg-green-500 text-white" : "bg-gray-200 text-gray-600"
                    }`}>2</div>
                    <div className={`flex-1 h-2 rounded ${status.communicationStarted ? "bg-green-500" : "bg-gray-200"}`}></div>
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
                      status.communicationStarted ? "bg-green-500 text-white" : "bg-gray-200 text-gray-600"
                    }`}>3</div>
                    <div className={`flex-1 h-2 rounded ${status.completed ? "bg-green-500" : "bg-gray-200"}`}></div>
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
                      status.completed ? "bg-green-500 text-white" : "bg-gray-200 text-gray-600"
                    }`}>4</div>
                  </div>
                  
                  <div className="flex justify-between mt-2 text-xs text-gray-600">
                    <span>Pay</span>
                    <span>Acknowledge</span>
                    <span>Contact</span>
                    <span>Complete</span>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="space-y-3">
                  {/* Payment Button */}
                  {!status.paymentDeposited && (
                    <button
                      onClick={() => handlePayment(lesson.id)}
                      disabled={!isRegisteredForCoin || userBalance === null || userBalance < LESSON_PRICE}
                      className={`w-full py-3 px-4 rounded-md font-medium transition-colors ${
                        !isRegisteredForCoin
                          ? "bg-gray-300 text-gray-600 cursor-not-allowed"
                          : userBalance === null || userBalance < LESSON_PRICE
                          ? "bg-red-100 text-red-700 cursor-not-allowed"
                          : "bg-blue-600 text-white hover:bg-blue-700"
                      }`}
                    >
                      {!isRegisteredForCoin
                        ? "Register for AptosCoin First"
                        : userBalance === null || userBalance < LESSON_PRICE
                        ? "Insufficient Balance"
                        : "Pay 1 APT"}
                    </button>
                  )}

                  {/* Waiting for teacher acknowledgment */}
                  {status.paymentDeposited && !status.acknowledged && (
                    <div className="text-center py-4 bg-yellow-50 rounded-md">
                      <p className="text-yellow-800 font-medium">Waiting for teacher to acknowledge payment</p>
                      <p className="text-yellow-600 text-sm mt-1">
                        The teacher will be notified of your payment and will acknowledge it soon.
                      </p>
                    </div>
                  )}

                  {/* Communication Started Button */}
                  {status.acknowledged && !status.communicationStarted && !canReportNonResponse && (
                    <div className="text-center py-4 bg-blue-50 rounded-md">
                      <p className="text-blue-800 font-medium">Teacher contact info is now available</p>
                      <p className="text-blue-600 text-sm mt-1 mb-3">
                        The teacher should contact you within 24 hours to start the lesson.
                      </p>
                      <button
                        onClick={() => handleCommunicationStarted(lesson.id)}
                        className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
                      >
                        Mark as "Teacher Contacted Me"
                      </button>
                    </div>
                  )}

                  {/* Non-Response Button (after 24 hours) */}
                  {canReportNonResponse && (
                    <div className="text-center py-4 bg-red-50 rounded-md">
                      <p className="text-red-800 font-medium">Teacher hasn't made contact</p>
                      <p className="text-red-600 text-sm mt-1 mb-3">
                        It's been {hoursSincePayment} hours since payment. You can report non-response.
                      </p>
                      <button
                        onClick={() => handleNonResponse(lesson.id)}
                        className="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 transition-colors"
                      >
                        Report Teacher Non-Response
                      </button>
                    </div>
                  )}

                  {/* Refund Button */}
                  {status.learnerReportedNonResponse && !status.refunded && (
                    <button
                      onClick={() => handleRefund(lesson.id)}
                      className="w-full py-3 px-4 rounded-md font-medium bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                    >
                      Claim Refund
                    </button>
                  )}

                  {/* Lesson in Progress */}
                  {status.communicationStarted && !status.completed && !status.refunded && (
                    <div className="text-center py-4 bg-green-50 rounded-md">
                      <p className="text-green-800 font-medium">Lesson in progress</p>
                      <p className="text-green-600 text-sm mt-1">
                        You and the teacher are now in contact. The lesson is underway!
                      </p>
                    </div>
                  )}

                  {/* Completed */}
                  {status.completed && (
                    <div className="text-center py-4 bg-green-50 rounded-md">
                      <p className="text-green-800 font-medium">✅ Lesson completed</p>
                      <p className="text-green-600 text-sm mt-1">
                        Payment has been released to the teacher.
                      </p>
                    </div>
                  )}

                  {/* Refunded */}
                  {status.refunded && (
                    <div className="text-center py-4 bg-blue-50 rounded-md">
                      <p className="text-blue-800 font-medium">💰 Refund processed</p>
                      <p className="text-blue-600 text-sm mt-1">
                        Your 1 APT has been refunded due to teacher non-response.
                      </p>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
