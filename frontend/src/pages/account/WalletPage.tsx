import { useEffect, useState } from "react";
import { Alert, Panel, Tag } from "../../components/ui";
import { formatDateTime, formatMinor } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { WalletData } from "../../lib/types";

export function AccountWalletPage() {
  const [data, setData] = useState<WalletData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.wallet
      .show()
      .then((d) => {
        if (cancelled) return;
        setData(d);
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setError(apiErrorMessage(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <div className="row">
        <span className="spinner" aria-hidden="true" />
        <span className="muted">Loading wallets</span>
      </div>
    );
  }

  if (error) return <Alert tone="error">{error}</Alert>;
  if (!data) return null;

  return (
    <div className="stack-lg">
      <Panel title="Wallet summary" sub="Wallet balances are reconciled against the append-only ledger on every read.">
        {data.wallets.length === 0 ? (
          <p className="muted mb-0">No wallets found.</p>
        ) : (
          <div className="stack">
            {data.wallets.map((w) => (
              <div key={w.id} className="panel panel--inset">
                <div className="row row--between">
                  <div>
                    <h4 className="mb-0">{w.kind} · {w.currency}</h4>
                    <p className="muted mb-0">Status: {w.status}</p>
                  </div>
                  <div className="row">
                    <Tag tone="gold">{w.real_money ? "Real money" : "Play money"}</Tag>
                    <span className="money money--gold">{formatMinor(w.balance_minor, w.currency)}</span>
                  </div>
                </div>
                <p className="dim mt-1 mb-0">Updated {formatDateTime(w.updated_at)}</p>
              </div>
            ))}
          </div>
        )}
      </Panel>
      <Panel title="Ledger reconciliation" sub="Discrepancies are zero by design. This is a live consistency report, not mocked.">
        {data.reconciliation.length === 0 ? (
          <p className="muted mb-0">No reconciliation data available.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Wallet</th>
                <th>Consistent</th>
                <th>Ledger total (minor)</th>
                <th>Wallet balance (minor)</th>
                <th>Discrepancy (minor)</th>
              </tr>
            </thead>
            <tbody>
              {data.reconciliation.map((r) => (
                <tr key={r.wallet_id}>
                  <td>#{r.wallet_id}</td>
                  <td>{r.consistent ? "Yes" : "No"}</td>
                  <td className="mono">{r.ledger_total_minor}</td>
                  <td className="mono">{r.wallet_balance_minor}</td>
                  <td className="mono">{r.discrepancy_minor}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      <Panel title="Deposits and withdrawals" sub="Not implemented in this foundation.">
        <p className="muted mb-0">
          Deposits and withdrawals return 501 (Not Implemented) because no licensed payment provider is
          configured. Real money wallets remain disabled by default.
        </p>
      </Panel>
    </div>
  );
}