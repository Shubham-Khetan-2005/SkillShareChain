import { useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { client, USER_STRUCT, decode, getAccountAddress } from "../lib/aptos";

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
      const res = await client.getAccountResource(address, USER_STRUCT);
      console.log("Raw profile data:", res);
      
      const profileData = {
        name: decode(res.data.name),
        skills: res.data.skills.map(decode),
      };
      
      console.log("Decoded profile data:", profileData);
      setData(profileData);
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
    <div className="mt-4">
      <p className="font-semibold">Hello, {data.name}!</p>
      <div className="mt-2">
        <p className="text-sm font-medium">Skills:</p>
        {data.skills.length === 0 ? (
          <p className="text-gray-500 text-sm">No skills added yet</p>
        ) : (
          <ul className="list-disc ml-5">
            {data.skills.map((skill, i) => (
              <li key={i} className="text-sm">{skill}</li>
            ))}
          </ul>
        )}
      </div>
      <p className="text-xs text-gray-400 mt-2">
        Address: {getAccountAddress(account)}
      </p>
    </div>
  );
}
