import { Link } from "react-router-dom";
import { Button, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { useBrand, useConfig } from "../context/ConfigContext";

export default function LegalPage({ document }: { document: "terms" | "privacy" }) {
  const brand = useBrand();
  const { config } = useConfig();
  const title = document === "terms" ? "Terms of service" : "Privacy policy";
  const note = config.legal?.note ?? "";

  return (
    <div>
      <PageHeader
        title={title}
        eyebrow="Legal"
        lead="Legal copy is configurable via platform settings and must be reviewed for the operating jurisdiction. The platform does not claim compliance in this foundation deployment."
      />
      <Panel>
        <h2>{brand.name} — {title}</h2>
        <p className="muted">
          This is a placeholder legal notice for the {brand.name} platform foundation. It is{" "}
          <strong>not</strong> legal advice and has not been approved for use in any regulated market.
        </p>
        <p>{note || "Content requires review for the specific operating jurisdiction before going live."}</p>
        <p>
          Deposits and withdrawals are not implemented in this deployment. Real money wallets are disabled
          by default. No games are live. Any references to wagering, real-money play or licensing must be
          updated before enabling real money.
        </p>
        <p className="dim mb-0">
          Last reviewed: not specified — this document must be updated before production launch.
        </p>
      </Panel>
      <div className="row mt-2">
        <Link to="/legal/terms" className="btn">
          Terms
        </Link>
        <Link to="/legal/privacy" className="btn">
          Privacy
        </Link>
      </div>
    </div>
  );
}