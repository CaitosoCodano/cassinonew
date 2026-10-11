import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import type { ReactNode } from "react";
import { useAuth } from "../context/AuthContext";
import { useBrand, useConfig } from "../context/ConfigContext";
import { Button } from "./ui";

function Monogram({ name }: { name: string }) {
  const initial = name.trim().charAt(0).toUpperCase() || "L";
  return (
    <span className="monogram" aria-hidden="true">
      {initial}
    </span>
  );
}

export function AppHeader() {
  const { user, status, logout } = useAuth();
  const brand = useBrand();
  const navigate = useNavigate();

  const navItem = ({ isActive }: { isActive: boolean }) =>
    `nav-link${isActive ? " is-active" : ""}`;

  return (
    <header className="site-header">
      <div className="shell header-inner">
        <Link to="/" className="brand">
          <Monogram name={brand.name} />
          <span className="brand-name">{brand.name}</span>
        </Link>
        <nav className="site-nav" aria-label="Primary">
          <NavLink to="/games" className={navItem}>
            Games
          </NavLink>
          <NavLink to="/responsible-gaming" className={navItem}>
            Responsible gaming
          </NavLink>
          <NavLink to="/legal/terms" className={navItem}>
            Legal
          </NavLink>
        </nav>
        <div className="header-auth">
          {status === "loading" ? (
            <span className="dim">…</span>
          ) : user ? (
            <>
              <NavLink to="/account" className={navItem}>
                My account
              </NavLink>
              {user.role === "admin" ? (
                <NavLink to="/admin" className={navItem}>
                  Admin
                </NavLink>
              ) : null}
              <Button
                size="sm"
                variant="default"
                onClick={() => {
                  void logout().then(() => navigate("/"));
                }}
              >
                Sign out
              </Button>
            </>
          ) : (
            <>
              <NavLink to="/login" className={navItem}>
                Sign in
              </NavLink>
              <Link to="/register">
                <Button size="sm" variant="primary">
                  Create account
                </Button>
              </Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

export function AppFooter() {
  const brand = useBrand();
  const { config } = useConfig();
  const { status, user } = useAuth();
  const canSelfExclude = status === "authenticated" && !!user;

  return (
    <footer className="site-footer">
      <div className="shell footer-inner">
        <div className="footer-brand">
          <p className="footer-brand-name">{brand.name}</p>
          <p className="dim">{brand.descriptor}</p>
        </div>
        <nav className="footer-nav" aria-label="Legal and support">
          <Link to="/legal/terms">Terms of service</Link>
          <Link to="/legal/privacy">Privacy policy</Link>
          <Link to="/responsible-gaming">Responsible gaming</Link>
          {canSelfExclude ? <Link to="/account/responsible-gaming">Self-exclusion</Link> : null}
          <a href={`mailto:${brand.support_email}`}>Contact support</a>
        </nav>
        <p className="footer-note dim">
          {brand.name} is a play-money platform. Deposits and withdrawals are not
          available in this deployment{config.real_money_enabled ? "" : " (play-money mode)"}. Please gamble
          responsibly.
        </p>
      </div>
    </footer>
  );
}

export function Layout({ children }: { children?: ReactNode }) {
  return (
    <div className="site">
      <AppHeader />
      <main className="site-main">
        <div className="shell">
          {/* Layout is mounted via <Route element={...}>, so the matched route
              renders into <Outlet />. `children` stays supported so the shell
              can be reused directly in tests. */}
          {children}
          <Outlet />
        </div>
      </main>
      <AppFooter />
    </div>
  );
}

export function PageLoading({ label = "Loading" }: { label?: string }): JSX.Element {
  return (
    <div className="row mt-3">
      <span className="spinner" aria-hidden="true" />
      <span className="muted">{label}</span>
    </div>
  );
}