import { Link } from "react-router-dom";
import { Eyebrow, Panel } from "../components/ui";
import { useBrand, useConfig } from "../context/ConfigContext";
import { useAuth } from "../context/AuthContext";

export default function HomePage() {
  const brand = useBrand();
  const { config, ready } = useConfig();
  const { status } = useAuth();

  return (
    <div className="stack-lg">
      <section className="hero">
        <Eyebrow>{ready ? "Platform foundation" : "Loading configuration"}</Eyebrow>
        <h1 className="hero-title">{brand.name}</h1>
        <p className="hero-descriptor">{brand.descriptor}</p>
        <div className="row">
          {status === "authenticated" ? (
            <Link className="btn btn--primary" to="/account">
              My account
            </Link>
          ) : (
            <Link className="btn btn--primary" to="/register">
              Create account
            </Link>
          )}
          <Link className="btn" to="/games">
            Game catalogue
          </Link>
        </div>
      </section>

      <section>
        <Eyebrow>What&apos;s live</Eyebrow>
        <div className="grid-3">
          <Panel title="Real accounts">
            Email + password registration, session management, account recovery and verification are fully
            operational and tested.
          </Panel>
          <Panel title="Wallets and ledger">
            Per-currency wallets (currently {config.currencies.filter((c) => c.enabled).map((c) => c.code).join(", ") || "none enabled"})
            backed by an append-only ledger. Admin adjustments are atomic and idempotent.
          </Panel>
          <Panel title="Responsible gaming">
            Deposit limits, cool-off and self-exclusion are real server-side controls, applied at transaction
            time — not cosmetic.
          </Panel>
        </div>
      </section>

      <section>
        <Eyebrow>Not live yet</Eyebrow>
        <div className="grid-3">
          <Panel title="Games">
            No titles are live in this deployment. The catalogue is served from a real integration registry;
            until an operator registers a provider there is nothing to play. This is intentional — no fake
            games, winners or jackpots are shown.
          </Panel>
          <Panel title="Deposits and withdrawals">
            Payments are not wired up: the API returns 501 until a licensed, compliant payment provider is
            integrated and jurisdictional review is complete.
          </Panel>
          <Panel title="Identity verification">
            The data model and review workflow exist; automated KYC is a future module and is not claimed here.
          </Panel>
        </div>
      </section>

      <section className="panel panel--inset">
        <p className="mb-0">
          <strong>Responsible play.</strong> Every account can set deposit limits and take a break from the
          platform at any time. See the{" "}
          <Link to="/responsible-gaming">responsible gaming</Link> page for the controls available.
        </p>
      </section>
    </div>
  );
}