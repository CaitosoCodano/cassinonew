import { Outlet, NavLink } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { PageHeader } from "../../components/ui";
import { useBrand } from "../../context/ConfigContext";

export function AccountLayout() {
  const { user } = useAuth();
  const brand = useBrand();
  const item = ({ isActive }: { isActive: boolean }) => `tab${isActive ? " active" : ""}`;

  return (
    <div>
      <PageHeader
        title="My account"
        eyebrow="Account"
        lead={`Signed in as ${user?.email ?? "—"}. Keep your personal details, wallets and security settings up to date.`}
      />
      <nav className="tabs" aria-label="Account sections">
        <NavLink to="/account" end className={item}>
          Overview
        </NavLink>
        <NavLink to="/account/profile" className={item}>
          Profile
        </NavLink>
        <NavLink to="/account/wallet" className={item}>
          Wallet
        </NavLink>
        <NavLink to="/account/transactions" className={item}>
          Transactions
        </NavLink>
        <NavLink to="/account/security" className={item}>
          Security
        </NavLink>
        <NavLink to="/account/sessions" className={item}>
          Sessions
        </NavLink>
        <NavLink to="/account/responsible-gaming" className={item}>
          Responsible gaming
        </NavLink>
        <NavLink to="/account/activity" className={item}>
          Activity
        </NavLink>
        <NavLink to="/account/support" className={item}>
          Support
        </NavLink>
      </nav>
      <Outlet />
    </div>
  );
}