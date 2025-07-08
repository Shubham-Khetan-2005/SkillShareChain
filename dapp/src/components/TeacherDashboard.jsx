import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  fetchTeacherRequests,
  acceptTeachRequest,
  getAccountAddress,
} from "../lib/aptos";

export default function TeacherDashboard() {
    const { account, signAndSubmitTransaction } = useWallet();
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(false);
    const [accepting, setAccepting] = useState(null);

    useEffect(() => {
        async function loadRequests() {
            if(!account) return setRequests([]);
            setLoading(true);
            const addr = getAccountAddress(account);
            const reqs = await fetchTeacherRequests(addr);
            setRequests(reqs);
            setLoading(false);
        }
        loadRequests();
    }, [account]);

    async function handleAccept(reqId){
        setAccepting(reqId);
        try {
            await acceptTeachRequest({
                requestId: reqId,
                signAndSubmitTransaction,
            });
            alert("Request accepted successfully!");
            //Refresh requests
            const addr = getAccountAddress(account);
            setRequests(await fetchTeacherRequests(addr)); 
        } catch(e) {
            alert("Failed to accept request: " + (e?.message || "Unknown error"));
        }
        setAccepting(null);
    }


    return (
        <div className="card p-4">
            <h2 className="text-xl font-bold mb-4">Teaching Requests</h2>
            {loading ? (
                <p>Loading...</p>
            ) : requests.length===0 ? (
                <p>No pending requests</p>
            ):(
                <ul className="space-y-3">
                    {requests.map(req => (
                        <li key={req.id} className="flex justify-between items-centre border-b pb-2">
                            <div>
                                <p>From: {req.learner}</p>
                                <p>Skill: {req.skill}</p>
                                <span className={`chip ${req.accepted ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                                    {req.accepted ? 'Accepted' : 'Pending'}
                                </span>
                            </div>
                            {!req.accepted && (
                                <button
                                    className="btn"
                                    disabled={accepting===req.id}
                                    onClick={()=> handleAccept(req.id)}
                                >
                                    {accepting===req.id ? "Accepting..." : "Accept"}
                                </button>
                            )}
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}