import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  fetchTeacherRequests,
  acceptTeachRequest,
  rejectTeachRequest,
  getAccountAddress,
  fetchProfile,
} from "../lib/aptos";

export default function TeacherDashboard() {
  const { account, signAndSubmitTransaction } = useWallet();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [accepting, setAccepting] = useState(null);
  const [rejecting, setRejecting] = useState(null);
  const [learnerNames, setLearnerNames] = useState({});

  useEffect(() => {
    async function loadRequests() {
      if (!account) return setRequests([]);
      setLoading(true);
      const addr = getAccountAddress(account);
      const reqs = await fetchTeacherRequests(addr);

      // Fetch learner names
      const learnerMap = {};
      await Promise.all(
        [...new Set(reqs.map(r => r.learner))].map(async learnerAddr => {
          const profile = await fetchProfile(learnerAddr);
          learnerMap[learnerAddr] = profile?.name || learnerAddr.slice(0, 8) + "...";
        })
      );
      setLearnerNames(learnerMap);
      setRequests(reqs);
      setLoading(false);
    }
    loadRequests();
  }, [account]);

  async function handleAccept(reqId) {
    setAccepting(reqId);
    try {
      await acceptTeachRequest({
        requestId: reqId,
        signAndSubmitTransaction,
      });
      alert("Request accepted successfully!");
      // Refresh
      const addr = getAccountAddress(account);
      setRequests(await fetchTeacherRequests(addr));
    } catch (e) {
      alert("Failed to accept request: " + (e?.message || "Unknown error"));
    }
    setAccepting(null);
  }

  async function handleReject(reqId) {
    setRejecting(reqId);
    try {
      await rejectTeachRequest({
        requestId: reqId,
        signAndSubmitTransaction,
      });
      alert("Request rejected successfully!");
      // Refresh
      const addr = getAccountAddress(account);
      setRequests(await fetchTeacherRequests(addr));
    } catch (e) {
      alert("Failed to reject request: " + (e?.message || "Unknown error"));
    }
    setRejecting(null);
  }

  return (
    <div className="card p-4">
      <h2 className="text-xl font-bold mb-4">Teaching Requests</h2>
      {loading ? (
        <p>Loading...</p>
      ) : requests.length === 0 ? (
        <p>No pending requests</p>
      ) : (
        <ul className="space-y-3">
          {requests
            .filter(req => !req.rejected) // Only show pending & accepted
            .map(req => (
            <li
              key={req.id}
              className="flex justify-between items-center border-b pb-2"
            >
              <div>
                <p>
                  From:{" "}
                  <span className="font-semibold">
                    {learnerNames[req.learner] || req.learner.slice(0, 8) + "..."}
                  </span>
                </p>
                <p>Skill: {req.skill}</p>
                <span
                  className={`chip ${
                    req.accepted
                      ? "bg-green-100 text-green-700"
                      : "bg-yellow-100 text-yellow-700"
                  }`}
                >
                  {req.accepted ? "Accepted" : "Pending"}
                </span>
              </div>
              <div className="flex gap-2">
                {!req.accepted ? (
                  <>
                    <button
                      className="btn bg-blue-600 text-white hover:bg-blue-700"
                      disabled={accepting === req.id || rejecting === req.id}
                      onClick={() => handleAccept(req.id)}
                    >
                      {accepting === req.id ? "Accepting..." : "Accept"}
                    </button>
                    <button
                      className="btn-outline border-red-600 text-red-600 hover:bg-red-50"
                      disabled={accepting === req.id || rejecting === req.id}
                      onClick={() => handleReject(req.id)}
                    >
                      {rejecting === req.id ? "Rejecting..." : "Reject"}
                    </button>
                  </>
                ) : (
                  <button className="btn bg-green-600 text-white cursor-default" disabled>
                    Accepted
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
