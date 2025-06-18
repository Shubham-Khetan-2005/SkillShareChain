import { useState } from "react";
import WalletProvider from "./WalletProvider";
import ConnectButton from "./components/ConnectButton";
import RegisterForm from "./components/RegisterForm";
import AddSkillForm from "./components/AddSkillForm";
import Profile from "./components/Profile";

export default function App() {
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const handleRegistrationSuccess = () => {
    setRefreshTrigger(prev => prev + 1); // Trigger profile refresh
  };

  const handleSkillAdded = () => {
    setRefreshTrigger(prev => prev + 1); // Trigger profile refresh
  };

  return (
    <WalletProvider>
      <div className="max-w-md mx-auto p-6 space-y-4">
        <h1 className="text-2xl font-bold">SkillShareChain MVP</h1>
        <ConnectButton />
        <RegisterForm onRegistrationSuccess={handleRegistrationSuccess} />
        <AddSkillForm onSkillAdded={handleSkillAdded} />
        <Profile refreshTrigger={refreshTrigger} />
      </div>
    </WalletProvider>
  );
}
