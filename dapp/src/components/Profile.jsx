import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { fetchProfile, getAccountAddress } from "../lib/aptos";

export default function Profile({ refreshTrigger }) {
  const { account } = useWallet();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function loadProfile() {
    if (!account) {
      setData(null);
      setError(null);
      return;
    }

    const address = getAccountAddress(account);
    if (!address) {
      setError("Cannot get wallet address");
      return;
    }

    console.log("Loading profile for address:", address);
    setLoading(true);
    setError(null);
    
    try {
      // const res = await client.getAccountResource(address, USER_STRUCT);
      // console.log("Raw profile data:", res);
      
      // const profileData = {
      //   name: decode(res.data.name),
      //   skills: res.data.skills.map(decode),
      // };
      
      // console.log("Decoded profile data:", profileData);
      // setData(profileData);

      setData(await fetchProfile(address));
    } catch (e) {
      console.log("Profile load error:", e.status, e.message);
      if (e.status === 404) {
        setData(null);
        setError(null);
      } else {
        setError("Error loading profile: " + e.message);
      }
    }
    setLoading(false);
  }

  useEffect(() => {
    loadProfile();
  }, [account, refreshTrigger]);

  if (loading) return <p>Loading profile...</p>;
  if (!account) return <p>Connect wallet to see profile.</p>;
  if (error) return <p className="text-red-500">{error}</p>;
  if (!data) return <p>No profile found. Register above.</p>;

  return (
  <>
    <h2 className="text-lg font-bold mb-3">{data.name}</h2>

    <p className="text-sm text-gray-600 mb-1">Skills</p>
    {data.skills.length === 0 ? (
      <p className="text-gray-400 text-sm">No skills yet.</p>
    ) : (
      <div className="flex flex-wrap gap-2">
        {data.skills.map((s, i) => (
          <span key={i} className="chip">{s}</span>
        ))}
      </div>
    )}
  </>
);
}