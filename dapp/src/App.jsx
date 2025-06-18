import { useState } from "react";
import WalletProvider from "./WalletProvider";
import ConnectButton from "./components/ConnectButton";
import RegisterForm from "./components/RegisterForm";
import AddSkillForm from "./components/AddSkillForm";
import Profile from "./components/Profile";

export default function App() {
  const [refresh, setRefresh] = useState(0);
  const bump = () => setRefresh((v) => v + 1);

  return (
    <WalletProvider>
      <main className="min-h-screen bg-gradient-to-br from-blue-50 to-blue-100 py-12">
        <div className="mx-auto w-full max-w-lg px-4 space-y-6">
          {/* header */}
          <header className="text-center">
            <h1 className="text-3xl font-extrabold text-blue-600">
              SkillShareChain
            </h1>
            <p className="text-sm text-gray-600">
              Trade knowledge, not just tokens.
            </p>
          </header>

          {/* wallet & forms in one card */}
          <section className="card space-y-4">
            <ConnectButton />
            <RegisterForm onRegistrationSuccess={bump} />
            <AddSkillForm onSkillAdded={bump} />
          </section>

          {/* profile appears below the options */}
          <section className="card">
            <Profile refreshTrigger={refresh} />
          </section>
        </div>
      </main>
    </WalletProvider>
  );
}
