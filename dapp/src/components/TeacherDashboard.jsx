import { useEffect, useState } from "react";
import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  fetchTeacherRequests,
  acceptTeachRequest,
  getAccountAddress,
} from "../lib/aptos";

export default function TeacherDashboard() {
    console.log("TeacherDashboard component rendering");

    const { account, signAndSubmitTransaction } = useWallet();
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(false);
    const [accepting, setAccepting] = useState(null);

    useEffect(() => {
    async function loadRequests() {
        console.log("loadRequests function called");
        
        if(!account) {
            console.log("No account found, returning early");
            return setRequests([]);
        }
        
        console.log("Account found, proceeding...");
        setLoading(true);
        
        const addr = getAccountAddress(account);
        console.log("Teacher address:", addr);
        console.log("Address is valid:", !!addr);
        
        if (!addr) {
            console.log("Address is null/undefined, cannot fetch requests");
            setLoading(false);
            return;
        }
        
        console.log("Calling fetchTeacherRequests...");
        const reqs = await fetchTeacherRequests(addr);
        console.log("Fetched requests:", reqs);
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
      // Refresh requests so accepted status is updated
      const addr = getAccountAddress(account);
      setRequests(await fetchTeacherRequests(addr));
    } catch (e) {
      alert("Failed to accept request: " + (e?.message || "Unknown error"));
    }
    setAccepting(null);
  }

  function handleReject(reqId) {
    setRejected(prev => ({ ...prev, [reqId]: true }));
  }

  return (
    <div className="card p-4">
      <h2 className="text-xl font-bold mb-4">Teaching Requests</h2>
      {loading ? (
        <p>Loading...</p>
      ) : requests.filter(r => !rejected[r.id]).length === 0 ? (
        <p>No pending requests</p>
      ) : (
        <ul className="space-y-3">
          {requests
            .filter(req => !rejected[req.id])
            .map(req => (
              <li key={req.id} className="flex justify-between items-center border-b pb-2">
                <div>
                  <p>From: {req.learner}</p>
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
                {!req.accepted ? (
                  <div className="flex gap-2">
                    <button
                      className="px-4 py-2 rounded bg-green-600 text-white font-semibold hover:bg-green-700 transition"
                      disabled={accepting === req.id}
                      onClick={() => handleAccept(req.id)}
                    >
                      {accepting === req.id ? "Accepting..." : "Accept"}
                    </button>
                    <button
                      className="px-4 py-2 rounded bg-red-500 text-white font-semibold hover:bg-red-700 transition"
                      onClick={() => handleReject(req.id)}
                    >
                      Reject
                    </button>
                  </div>
                ) : (
                  <button
                    className="px-4 py-2 rounded font-semibold bg-green-500 text-white cursor-default"
                    disabled
                  >
                    Accepted
                  </button>
                )}
              </li>
            ))}
        </ul>
      )}
    </div>
  );
}

