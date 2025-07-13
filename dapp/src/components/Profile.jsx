import { useEffect, useState, useCallback } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchProfile, getAccountAddress } from "../lib/aptos";

export default function Profile({ refreshTrigger }) {
  const { account } = useWallet();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Use useCallback to avoid unnecessary re-creations
  const loadProfile = useCallback(async () => {
    if (!account) {
      setData(null);
      setError(null);
      return;
    }

    const address = getAccountAddress(account);
    if (!address) {
      setError("Cannot get wallet address");
      setData(null);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const profile = await fetchProfile(address);
      setData(profile);
      setError(null);
    } catch (e) {
      // Defensive error handling for unknown error shapes
      let message = "Unknown error";
      if (e && typeof e === "object") {
        if (e.status === 404) {
          setData(null);
          setError(null);
          setLoading(false);
          return;
        }
        message = e.message || e.error || JSON.stringify(e);
      } else if (typeof e === "string") {
        message = e;
      }
      setError("Error loading profile: " + message);
      setData(null);
    }
    setLoading(false);
  }, [account]);

  useEffect(() => {
    loadProfile();
    // eslint-disable-next-line
  }, [account, refreshTrigger, loadProfile]);

  if (loading) return <p>Loading profile...</p>;
  if (!account) return <p>Connect wallet to see profile.</p>;
  if (error)
    return (
      <div>
        <p className="text-red-500">{error}</p>
        <button
          className="mt-2 px-3 py-1 bg-blue-500 text-white rounded"
          onClick={loadProfile}
        >
          Retry
        </button>
      </div>
    );
  if (!data)
    return <p>No profile found. Register above.</p>;

  return (
    <>
      <h2 className="text-lg font-bold mb-3">{data.name}</h2>
      <p className="text-sm text-gray-600 mb-1">Skills</p>
      {Array.isArray(data.skills) && data.skills.length === 0 ? (
        <p className="text-gray-400 text-sm">No skills yet.</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {Array.isArray(data.skills) &&
            data.skills.map((s, i) => (
              <span key={i} className="chip">
                {s}
              </span>
            ))}
        </div>
      )}
    </>
  );
}
