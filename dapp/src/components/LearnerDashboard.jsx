import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchLearnerRequests, getAccountAddress, fetchProfile } from "../lib/aptos";

export default function LearnerDashboard() {
  const { account } = useWallet();
  const [requests, setRequests] = useState([]);
  const [teacherNames, setTeacherNames] = useState({});

  useEffect(() => {
    async function loadRequests() {
      if (!account) return setRequests([]);
      const learnerAddr = getAccountAddress(account);
      const reqs = await fetchLearnerRequests(learnerAddr);

      // Fetch all unique teacher names
      const uniqueTeachers = [...new Set(reqs.map(r => r.teacher))];
      const nameMap = {};
      await Promise.all(
        uniqueTeachers.map(async (teacherAddr) => {
          const profile = await fetchProfile(teacherAddr);
          nameMap[teacherAddr] = profile?.name || teacherAddr.slice(0, 8) + "...";
        })
      );
      setTeacherNames(nameMap);
      setRequests(reqs);
    }
    loadRequests();
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
                <p>
                  To:{" "}
                  <span className="font-semibold">
                    {teacherNames[req.teacher] || req.teacher.slice(0, 8) + "..."}
                  </span>
                </p>
                <p>Skill: {req.skill}</p>
                <span
                  className={`chip ${
                    req.accepted
                      ? "bg-green-100 text-green-700"
                      : req.rejected
                      ? "bg-red-100 text-red-700"
                      : "bg-yellow-100 text-yellow-700"
                  }`}
                >
                  {req.accepted
                    ? "Accepted"
                    : req.rejected
                    ? "Rejected"
                    : "Pending"}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
