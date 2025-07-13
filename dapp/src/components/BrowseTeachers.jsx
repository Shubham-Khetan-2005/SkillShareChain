import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchAllTeachers, sendTeachRequest, getAccountAddress } from "../lib/aptos";

export default function BrowseTeachers() {
  const [teachers, setTeachers] = useState([]);
  const [loading, setLoading] = useState(false);
  const { account, signAndSubmitTransaction } = useWallet();
  const [requesting, setRequesting] = useState({});
  const [selectedSkills, setSelectedSkills] = useState({});

  const learnerAddr = account ? getAccountAddress(account) : null;

  useEffect(() => {
    setLoading(true);
    fetchAllTeachers().then((users) => {
      setTeachers(users.filter((u) => u.address !== learnerAddr));
      setLoading(false);
    });
  }, [learnerAddr]);

  function localKey(learnerAddr, teacherAddr, skill) {
    return `requested:${learnerAddr}:${teacherAddr}:${skill}`;
  }

  function isSkillRequested(learnerAddr, teacherAddr, skill) {
    if (!learnerAddr) return false;
    return !!localStorage.getItem(localKey(learnerAddr, teacherAddr, skill));
  }

  function markSkillRequested(learnerAddr, teacherAddr, skill) {
    if (!learnerAddr) return;
    localStorage.setItem(localKey(learnerAddr, teacherAddr, skill), "1");
  }

  async function handleRequest(teacher, skill) {
    if (!account) return alert("Connect wallet first");
    setRequesting((prev) => ({ ...prev, [teacher.address]: skill }));
    try {
      await sendTeachRequest({
        teacher: teacher.address,
        skill,
        signAndSubmitTransaction,
      });
      markSkillRequested(learnerAddr, teacher.address, skill);
      alert("Request sent successfully!");
    } catch (e) {
      alert("Failed to send request: " + (e?.message || "Unknown error"));
    }
    setRequesting((prev) => ({ ...prev, [teacher.address]: null }));
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
              {teacher.skills.length === 0 ? (
                <span className="text-sm text-gray-400">No skills listed</span>
              ) : (
                <>
                  <div className="flex flex-wrap gap-2 mt-1">
                    {teacher.skills.map((skill, i) => (
                      <span key={i} className="chip">
                        {skill}
                      </span>
                    ))}
                  </div>
                  <select
                    className="mt-2 border rounded px-2 py-1"
                    value={selectedSkills[teacher.address] || ""}
                    onChange={(e) =>
                      setSelectedSkills((prev) => ({
                        ...prev,
                        [teacher.address]: e.target.value,
                      }))
                    }
                  >
                    <option value="" disabled>
                      Select a skill to request
                    </option>
                    {teacher.skills.map((skill) => (
                      <option key={skill} value={skill}>
                        {skill}
                      </option>
                    ))}
                  </select>
                  <button
                    className={`btn mt-2 ml-2 ${
                      selectedSkills[teacher.address] &&
                      isSkillRequested(
                        learnerAddr,
                        teacher.address,
                        selectedSkills[teacher.address]
                      )
                        ? "bg-green-200 text-green-800 cursor-default"
                        : "bg-blue-600 text-white"
                    }`}
                    disabled={
                      !selectedSkills[teacher.address] ||
                      isSkillRequested(
                        learnerAddr,
                        teacher.address,
                        selectedSkills[teacher.address]
                      ) ||
                      requesting[teacher.address]
                    }
                    onClick={() =>
                      handleRequest(
                        teacher,
                        selectedSkills[teacher.address] || teacher.skills[0]
                      )
                    }
                  >
                    {requesting[teacher.address]
                      ? "Requesting..."
                      : selectedSkills[teacher.address] &&
                        isSkillRequested(
                          learnerAddr,
                          teacher.address,
                          selectedSkills[teacher.address]
                        )
                      ? "Requested"
                      : "Request Lesson"}
                  </button>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
