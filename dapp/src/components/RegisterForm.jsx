import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  client,
  USER_STRUCT,
  REGISTER_FN,
  encode,
  buildPayload,
  getAccountAddress,
} from "../lib/aptos";

export default function RegisterForm({ onRegistrationSuccess }) {
  const { account, signAndSubmitTransaction } = useWallet();
  const [nick, setNick] = useState("");

  async function register() {
    if (!account) {
      alert("Connect wallet first");
      return;
    }
    
    const address = getAccountAddress(account);
    if (!address) {
      alert("Cannot get wallet address");
      return;
    }
    
    if (!nick.trim()) {
      alert("Enter a nickname");
      return;
    }

    console.log("Checking profile for address:", address);
    
    // Check if profile exists
    try {
      const resource = await client.getAccountResource(address, USER_STRUCT);
      console.log("Profile already exists:", resource);
      alert("Profile already exists on this wallet.");
      return;
    } catch (e) {
      console.log("Profile check result:", e.status, e.message);
      // If 404, user doesn't exist - proceed with registration
      if (e.status !== 404) {
        alert("Error checking profile: " + e.message);
        return;
      }
    }

    // Submit registration transaction
    try {
      console.log("Submitting registration for:", address);
      const result = await signAndSubmitTransaction(
        buildPayload(REGISTER_FN, [encode(nick.trim())])
      );
      console.log("Registration result:", result);
      setNick("");
      alert("Registration successful!");
      
      if (onRegistrationSuccess) {
        onRegistrationSuccess();
      }
    } catch (e) {
      console.error("Registration error:", e);
      alert("Registration failed: " + (e?.message || "Unknown error"));
    }
  }

  return (
    <div className="space-x-2">
      <input
        className="border px-2 py-1"
        value={nick}
        onChange={(e) => setNick(e.target.value)}
        placeholder="nickname"
      />
      <button 
        onClick={register} 
        className="bg-blue-600 text-white px-3 py-1"
        disabled={!account}
      >
        {account ? "Register" : "Connect Wallet"}
      </button>
      {account && (
        <p className="text-xs text-gray-500 mt-1">
          Address: {getAccountAddress(account)}
        </p>
      )}
    </div>
  );
}
