import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { ADD_SKILL_FN, encode, buildPayload } from "../lib/aptos";

export default function AddSkillForm({ onSkillAdded }) {
  const { account, signAndSubmitTransaction } = useWallet();
  const [skill, setSkill] = useState("");

  async function addSkill() {
    if (!account) {
      alert("Connect wallet first");
      return;
    }
    if (!skill.trim()) return;

    try {
      await signAndSubmitTransaction(
        buildPayload(ADD_SKILL_FN, [encode(skill.trim())])
      );
      setSkill("");
      
      // Trigger profile refresh
      if (onSkillAdded) {
        onSkillAdded();
      }
    } catch (e) {
      console.error("Add skill error:", e);
      alert("Failed to add skill: " + (e?.message || "Unknown error"));
    }
  }

  return (
    <div className="space-x-2 mt-4">
      <input
        className="border px-2 py-1"
        value={skill}
        onChange={(e) => setSkill(e.target.value)}
        placeholder="new skill"
      />
      <button
        onClick={addSkill}
        className="bg-green-600 text-white px-3 py-1"
        disabled={!account}
      >
        Add Skill
      </button>
    </div>
  );
}
