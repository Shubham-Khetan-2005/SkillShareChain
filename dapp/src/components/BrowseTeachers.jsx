import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchAllTeachers, sendTeachRequest, getAccountAddress } from "../lib/aptos";

export default function BrowseTeachers() {
    const [teachers, setTeachers] = useState([]);
    const [loading, setLoading] = useState(false);
    const { account, signAndSubmitTransaction } = useWallet();
    const [requesting, setRequesting] = useState(null);
    const [selectedSkills, setSelectedSkills] = useState({}); // teacherAddr -> skill

    useEffect(() => {
        setLoading(true);
        fetchAllTeachers().then((users) => {
            const myAddr = account ? getAccountAddress(account) : null;
            setTeachers(users.filter(u => u.address !== myAddr));
            setLoading(false);
        });
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
                                    <span key={i} className="chip">{skill}</span>
                                ))}
                            </div>
                            {teacher.skills.length > 1 && (
                                <select
                                    className="mt-2 rounded border px-2 py-1"
                                    value={selectedSkills[teacher.address] || teacher.skills[0]}
                                    onChange={e => handleSkillChange(teacher.address, e.target.value)}
                                >
                                    {teacher.skills.map((skill, i) => (
                                        <option key={i} value={skill}>{skill}</option>
                                    ))}
                                </select>
                            )}
                            <button
                                className="btn mt-2 ml-2"
                                disabled={requesting === teacher.address}
                                onClick={() => handlerequest(teacher)}
                            >
                                {requesting === teacher.address ? "Requesting..." : "Request Lesson"}
                            </button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
