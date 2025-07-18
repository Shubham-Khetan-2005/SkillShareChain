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
  const [contactInfo, setContactInfo] = useState(""); // ✅ Add contact info state
  const [busy, setBusy] = useState(false);

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

    // ✅ Add contact info validation
    if (!contactInfo.trim()) {
      alert("Enter contact information");
      return;
    }

    setBusy(true);
    try {
      /* 1 ─ duplicate-profile guard (cheap view call) */
      if (await userExists(address)) {
        alert("Profile already exists on this wallet.");
        return;
      }

      /* 2 ─ submit on-chain tx with contact info */
      await signAndSubmitTransaction(
        buildPayload(REGISTER_FN, [
          encode(nick.trim()),
          encode(contactInfo.trim()) // ✅ Add contact info parameter
        ])
      );

      setNick("");
      setContactInfo(""); // ✅ Clear contact info
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
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!busy) register();
      }}
      className="space-y-4" // ✅ Change from flex to vertical stack
    >
      <div>
        <label htmlFor="nickname" className="block text-sm font-medium text-gray-700 mb-1">
          Nickname
        </label>
        <input
          id="nickname"
          className="w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm
                     focus:border-blue-500 focus:ring-blue-500"
          value={nick}
          onChange={(e) => setNick(e.target.value)}
          placeholder="Enter your nickname"
          disabled={busy}
        />
      </div>
      
      {/* ✅ Add contact info input */}
      <div>
        <label htmlFor="contact" className="block text-sm font-medium text-gray-700 mb-1">
          Contact Information
        </label>
        <textarea
          id="contact"
          className="w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm
                     focus:border-blue-500 focus:ring-blue-500"
          value={contactInfo}
          onChange={(e) => setContactInfo(e.target.value)}
          placeholder="Discord: username#1234, Email: your@email.com"
          rows={3}
          disabled={busy}
        />
        <p className="text-xs text-gray-500 mt-1">
          This will be shared with learners after they pay for lessons
        </p>
      </div>

      <button
        type="submit"
        className="w-full btn disabled:opacity-50"
        disabled={busy || !account}
      >
        {busy ? "Registering…" : "Register"}
      </button>
    </form>
  );
}
