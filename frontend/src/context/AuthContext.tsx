import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { api, ApiError, resetCsrf } from "../lib/api";
import type { User } from "../lib/types";

type AuthStatus = "loading" | "anonymous" | "authenticated";

interface AuthContextValue {
  user: User | null;
  status: AuthStatus;
  /** Re-check the session cookie (call after login/logout or verify). */
  refresh: () => Promise<void>;
  login: (email: string, password: string) => Promise<User>;
  logout: () => Promise<void>;
  logoutAll: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [status, setStatus] = useState<AuthStatus>("loading");

  const refresh = useCallback(async () => {
    try {
      const u = await api.auth.session();
      setUser(u);
      setStatus(u ? "authenticated" : "anonymous");
    } catch {
      resetCsrf();
      setUser(null);
      setStatus("anonymous");
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const login = useCallback(
    async (email: string, password: string) => {
      const u = await api.auth.login(email, password);
      setUser(u);
      setStatus("authenticated");
      await refresh();
      return u;
    },
    [refresh],
  );

  const logout = useCallback(async () => {
    await api.auth.logout();
    setUser(null);
    setStatus("anonymous");
  }, []);

  const logoutAll = useCallback(async () => {
    await api.auth.logoutAll();
    setUser(null);
    setStatus("anonymous");
  }, []);

  return (
    <AuthContext.Provider value={{ user, status, refresh, login, logout, logoutAll }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within <AuthProvider>");
  return ctx;
}

/** True when the user holds the admin role (authoritative check is server-side). */
export function useIsAdmin(): boolean {
  const { user } = useAuth();
  return user?.role === "admin";
}

export { ApiError };