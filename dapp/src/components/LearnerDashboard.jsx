import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchLearnerRequests, getAccountAddress } from "../lib/aptos";

export default function LearnerDashboard() {
  const { account } = useWallet();
  const [requests, setRequests] = useState([]);

  useEffect(() => {
    if (account) {
      fetchLearnerRequests(getAccountAddress(account)).then(setRequests);
    }
  }, [account]);

  return (
    <div className="card p-4">
      <h2 className="text-xl font-bold mb-4">My Learning Requests</h2>
      {requests.length === 0 ? (
        <p>No outgoing requests.</p>
      ) : (
        <ul className="space-y-3">
          {requests.map(req => (
            <li key={req.id} className="flex justify-between items-center border-b pb-2">
              <div>
                <p>To: {req.teacher}</p>
                <p>Skill: {req.skill}</p>
                <span className="chip">{req.accepted ? "Accepted" : "Pending"}</span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
