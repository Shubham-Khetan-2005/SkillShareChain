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
    <form
      onSubmit={(e) => {
        e.preventDefault();
        addSkill();
      }}
      className="flex gap-2"
    >
      <input
        className="flex-1 rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm
                   focus:border-rose-500 focus:ring-rose-500"
        value={skill}
        onChange={(e) => setSkill(e.target.value)}
        placeholder="new skill"
      />
      <button type="submit" className="btn-outline">
        Add Skill
      </button>
    </form>
  );
}