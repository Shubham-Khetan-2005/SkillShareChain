import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  fetchAllTeachers,
  fetchLearnerRequests,
  sendTeachRequest,
  getAccountAddress,
} from "../lib/aptos";

export default function BrowseTeachers() {
  const [teachers, setTeachers] = useState([]);
  const [loading, setLoading] = useState(false);
  const { account, signAndSubmitTransaction } = useWallet();
  const [requesting, setRequesting] = useState(null);
  const [selectedSkills, setSelectedSkills] = useState({});
  const [requestedTeachers, setRequestedTeachers] = useState({});

  // On mount, fetch all teachers and all my outgoing requests
  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      const myAddr = account ? getAccountAddress(account) : null;

      // 1. Fetch all teachers except myself
      const allTeachers = await fetchAllTeachers();
      setTeachers(allTeachers.filter(u => u.address !== myAddr));

      // 2. Fetch all requests sent by me (persistent)
      if (myAddr) {
        const myRequests = await fetchLearnerRequests(myAddr);
        // Build a map of teacher addresses whom I have requested
        const requested = {};
        for (const req of myRequests) {
          requested[req.teacher] = true;
        }
        setRequestedTeachers(requested);
      } else {
        setRequestedTeachers({});
      }
      setLoading(false);
    }
    fetchData();
  }, [account]);

  function handleSkillChange(teacherAddr, skill) {
    setSelectedSkills((prev) => ({
      ...prev,
      [teacherAddr]: skill,
    }));
  }

  async function handlerequest(teacher) {
    if (!account) return alert("Connect wallet first");
    if (!teacher.skills.length) return alert("Teacher has no skills listed.");
    const skill = selectedSkills[teacher.address] || teacher.skills[0];
    setRequesting(teacher.address);
    try {
      await sendTeachRequest({
        teacher: teacher.address,
        skill,
        signAndSubmitTransaction,
      });
      // Mark as requested (immediate feedback)
      setRequestedTeachers((prev) => ({
        ...prev,
        [teacher.address]: true,
      }));
      alert("Request sent successfully!");
    } catch (e) {
      console.error(e);
      alert("Failed to send request: " + (e?.message || "Unknown error"));
    }
    setRequesting(null);
  }

  return (
    <div className="card p-4">
      <h2 className="text-xl font-bold mb-4">Browse Teachers</h2>
      {loading ? (
        <p>Loading...</p>
      ) : teachers.length === 0 ? (
        <p>No teachers found.</p>
      ) : (
        <div className="space-y-4">
          {teachers.map((teacher) => (
            <div key={teacher.address} className="border-b pb-3">
              <div className="font-bold">{teacher.name}</div>
              <div className="flex flex-wrap gap-2 mt-1">
                {teacher.skills.map((skill, i) => (
                  <span key={i} className="chip">
                    {skill}
                  </span>
                ))}
              </div>
              {teacher.skills.length > 1 && (
                <select
                  className="mt-2 rounded border px-2 py-1"
                  value={selectedSkills[teacher.address] || teacher.skills[0]}
                  onChange={e => handleSkillChange(teacher.address, e.target.value)}
                >
                  {teacher.skills.map((skill, i) => (
                    <option key={i} value={skill}>
                      {skill}
                    </option>
                  ))}
                </select>
              )}
              <button
                className={
                  `mt-2 ml-2 px-4 py-2 rounded text-white font-semibold transition ` +
                  (requestedTeachers[teacher.address]
                    ? "bg-gray-400 cursor-not-allowed"
                    : requesting === teacher.address
                    ? "bg-blue-300"
                    : "bg-blue-600 hover:bg-blue-700")
                }
                disabled={
                  requestedTeachers[teacher.address] ||
                  requesting === teacher.address
                }
                onClick={() => handlerequest(teacher)}
              >
                {requestedTeachers[teacher.address]
                  ? "Requested"
                  : requesting === teacher.address
                  ? "Requesting..."
                  : "Request Lesson"}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
