import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import type { ReactNode } from "react";
import { Layout } from "./components/Layout";
import { useAuth } from "./context/AuthContext";
import { PageLoading } from "./components/Layout";
import HomePage from "./pages/HomePage";
import GamesLobbyPage from "./pages/GamesLobbyPage";
import GamePage from "./pages/GamePage";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import VerifyEmailPage from "./pages/VerifyEmailPage";
import { AccountLayout } from "./pages/account/AccountLayout";
import { AccountOverviewPage } from "./pages/account/OverviewPage";
import { AccountProfilePage } from "./pages/account/ProfilePage";
import { AccountWalletPage } from "./pages/account/WalletPage";
import { AccountTransactionsPage } from "./pages/account/TransactionsPage";
import { AccountSecurityPage } from "./pages/account/SecurityPage";
import { AccountSessionsPage } from "./pages/account/SessionsPage";
import { AccountResponsibleGamingPage } from "./pages/account/ResponsibleGamingPage";
import { AccountActivityPage } from "./pages/account/ActivityPage";
import { AccountSupportPage } from "./pages/account/SupportPage";
import AdminPage from "./pages/AdminPage";
import AdminGamesPage from "./pages/AdminGamesPage";
import LegalPage from "./pages/LegalPage";
import ResponsibleGamingPage from "./pages/ResponsibleGamingPage";
import NotFoundPage from "./pages/NotFoundPage";

/** Redirects signed-in visitors away from guest-only pages (login, register). */
function GuestOnly({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  if (status === "loading") return <PageLoading label="Checking session" />;
  if (status === "authenticated") return <Navigate to="/account" replace />;
  return children as JSX.Element;
}

/** Requires an authenticated user; otherwise redirects to sign-in. */
function RequireAuth({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const location = useLocation();
  if (status === "loading") return <PageLoading label="Checking session" />;
  if (status !== "authenticated") {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return children as JSX.Element;
}

/** Requires the admin role (server enforces this too, with a 403 on mismatch). */
function RequireAdmin({ children }: { children: ReactNode }) {
  const { user, status } = useAuth();
  if (status === "loading") return <PageLoading label="Checking session" />;
  if (status !== "authenticated") return <Navigate to="/login" replace />;
  if (user?.role !== "admin") return <Navigate to="/account" replace />;
  return children as JSX.Element;
}

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/games" element={<GamesLobbyPage />} />
        <Route path="/games/:slug" element={<GamePage />} />
        <Route path="/login" element={<GuestOnly><LoginPage /></GuestOnly>} />
        <Route path="/register" element={<GuestOnly><RegisterPage /></GuestOnly>} />
        <Route path="/forgot-password" element={<GuestOnly><ForgotPasswordPage /></GuestOnly>} />
        <Route path="/reset-password" element={<GuestOnly><ResetPasswordPage /></GuestOnly>} />
        <Route path="/verify-email" element={<VerifyEmailPage />} />

        <Route
          path="/account"
          element={
            <RequireAuth>
              <AccountLayout />
            </RequireAuth>
          }
        >
          <Route index element={<AccountOverviewPage />} />
          <Route path="profile" element={<AccountProfilePage />} />
          <Route path="wallet" element={<AccountWalletPage />} />
          <Route path="transactions" element={<AccountTransactionsPage />} />
          <Route path="security" element={<AccountSecurityPage />} />
          <Route path="sessions" element={<AccountSessionsPage />} />
          <Route path="responsible-gaming" element={<AccountResponsibleGamingPage />} />
          <Route path="activity" element={<AccountActivityPage />} />
          <Route path="support" element={<AccountSupportPage />} />
        </Route>

        <Route
          path="/admin"
          element={
            <RequireAdmin>
              <AdminPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/games"
          element={
            <RequireAdmin>
              <AdminGamesPage />
            </RequireAdmin>
          }
        />

        <Route path="/legal/terms" element={<LegalPage document="terms" />} />
        <Route path="/legal/privacy" element={<LegalPage document="privacy" />} />
        <Route path="/responsible-gaming" element={<ResponsibleGamingPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  );
}