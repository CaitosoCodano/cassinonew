import { Link } from "react-router-dom";
import { Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { useConfig } from "../context/ConfigContext";

export default function ResponsibleGamingPage() {
  const { config } = useConfig();

  return (
    <div>
      <PageHeader
        title="Responsible gaming"
        eyebrow="Player protection"
        lead="Player protection tools are real, server-side controls. They are available to all signed-in accounts and cannot be bypassed from the browser."
      />
      <div className="grid-2">
        <Panel title="Deposit limits" sub="Set per-period deposit limits.">
          <p className="muted">
            You can set deposit, loss or session limits via the account dashboard. The backend enforces
            limits at the point of attempting a transaction; requests that would breach an active limit
            are rejected.
          </p>
          <Link className="btn" to="/account/responsible-gaming">
            Manage limits
          </Link>
        </Panel>
        <Panel title="Cool-off" sub="Take a short break.">
          <p className="muted">
            Cool-off periods are recorded as account restrictions. The platform enforces session blocking
            and rejects play while a cool-off is active.
          </p>
          <p className="dim">Default cool-off hours: {config.self_exclusion.cool_off_hours}</p>
        </Panel>
        <Panel title="Self-exclusion" sub="Exclude yourself for a fixed period or open-ended.">
          <p className="muted">
            Self-exclusion is a real restriction. Applying it revokes all active sessions and prevents
            access for the selected duration. The minimum duration configured for this deployment is{" "}
            {config.self_exclusion.self_exclusion_min_days} day(s).
          </p>
          <Link className="btn" to="/account/responsible-gaming">
            Apply self-exclusion
          </Link>
        </Panel>
        <Panel title="Support and help" sub="Reach out if you need help.">
          <p className="muted">
            If you need support related to responsible gaming, use the account support section or email
            the support address listed in the footer. This foundation does not provide real gambling
            services.
          </p>
          <Link className="btn" to="/account/support">
            Contact support
          </Link>
        </Panel>
      </div>
    </div>
  );
}