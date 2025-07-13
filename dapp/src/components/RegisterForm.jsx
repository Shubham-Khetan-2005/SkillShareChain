import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import {
  userExists,
  REGISTER_FN,
  encode,
  buildPayload,
  getAccountAddress,
} from "../lib/aptos";

export default function RegisterForm({ onRegistrationSuccess }) {
  const { account, signAndSubmitTransaction } = useWallet();
  const [nick, setNick] = useState("");
  const [busy, setBusy]   = useState(false);

  
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

  setBusy(true);
    try {
      /* 1 ─ duplicate-profile guard (cheap view call) */
      if (await userExists(address)) {
        alert("Profile already exists on this wallet.");
        return;
      }

      /* 2 ─ submit on-chain tx */
      await signAndSubmitTransaction(
        buildPayload(REGISTER_FN, [encode(nick.trim())])
      );

      setNick("");
      alert("Registration successful!");
      onRegistrationSuccess?.();
    } catch (e) {
      console.error(e);
      if (String(e).includes("rejected")) {
        alert("Transaction cancelled");
      } else {
        alert("Registration failed: " + (e?.message || "unknown error"));
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!busy) register();
      }}
      className="flex gap-2"
    >
      <input
        className="flex-1 rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm
                   focus:border-blue-500 focus:ring-blue-500"
        value={nick}
        onChange={(e) => setNick(e.target.value)}
        placeholder="nickname"
        disabled={busy}
      />
      <button
        type="submit"
        className="btn disabled:opacity-50"
        disabled={busy || !account}
      >
        {busy ? "Registering…" : "Register"}
      </button>
    </form>
  );
}