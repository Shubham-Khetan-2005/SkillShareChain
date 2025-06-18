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
    <form
      onSubmit={(e) => {
        e.preventDefault();
        register();
      }}
      className="flex gap-2"
    >
      <input
        className="flex-1 rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm
                   focus:border-rose-500 focus:ring-rose-500"
        value={nick}
        onChange={(e) => setNick(e.target.value)}
        placeholder="nickname"
      />
      <button type="submit" className="btn">
        Register
      </button>
    </form>
  );
}