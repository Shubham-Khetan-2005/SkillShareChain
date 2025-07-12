import { useState } from "react";
import WalletProvider from "./WalletProvider";
import ConnectButton from "./components/ConnectButton";
import RegisterForm from "./components/RegisterForm";
import AddSkillForm from "./components/AddSkillForm";
import Profile from "./components/Profile";
import BrowseTeachers from "./components/BrowseTeachers";
import TeacherDashboard from "./components/TeacherDashboard";
import LearnerDashboard from "./components/LearnerDashboard"; 
import LearnerDashboard from "./components/LearnerDashboard";

export default function App() {
  const [refresh, setRefresh] = useState(0);
  const [page, setPage] = useState("home");
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

          {/* NAVIGATION */}
          <nav className="flex gap-2 justify-center mb-2">
            <button
              className={`btn-outline ${page === "home" ? "bg-blue-100" : ""}`}
              onClick={() => setPage("home")}
            >
              My Profile
            </button>
            <button
              className={`btn-outline ${page === "browse" ? "bg-blue-100" : ""}`}
              onClick={() => setPage("browse")}
            >
              Browse Teachers
            </button>
            <button
              className={`btn-outline ${page === "dashboard" ? "bg-blue-100" : ""}`}
              onClick={() => setPage("dashboard")}
            >
              Teacher DashBoard
            </button>
            <button
              className={`btn-outline ${page === "dashboard" ? "bg-blue-100" : ""}`}
              onClick={() => setPage("yourdashboard")}
            >
              Learner DashBoard
            </button>
          </nav>

          {/* Page Content */}
          {page === "home" && (
            <>
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
            </>
          )}

          {page === "browse" && <BrowseTeachers/>}
          {page === "dashboard" && <TeacherDashboard/>}
          {page === "yourdashboard" && <LearnerDashboard/>}
          
        </div>
      </main>
    </WalletProvider>
  );
}
