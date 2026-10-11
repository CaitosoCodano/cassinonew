import { useEffect, useState } from "react";
import { Alert, Panel } from "../../components/ui";
import { formatDateTime, formatMinor } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { Transaction } from "../../lib/types";

export function AccountTransactionsPage() {
  const [txs, setTxs] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.wallet
      .transactions({ per_page: 100, page: 1 } as any)
      .then((res) => {
        if (cancelled) return;
        setTxs(res.data);
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
        <span className="muted">Loading transactions</span>
      </div>
    );
  }

  if (error) return <Alert tone="error">{error}</Alert>;

  return (
    <Panel title="Transaction history" sub="All movement is written to the append-only ledger and reflected here.">
      {txs.length === 0 ? (
        <p className="muted mb-0">No transactions yet.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Kind</th>
              <th>Status</th>
              <th>Description</th>
              <th>Amount</th>
              <th>Balance after</th>
            </tr>
          </thead>
          <tbody>
            {txs.map((t) => (
              <tr key={t.id}>
                <td>{formatDateTime(t.created_at)}</td>
                <td>{t.kind}</td>
                <td>{t.status}</td>
                <td>{t.description ?? "—"}</td>
                <td className={`money${t.amount_minor >= 0 ? " amount-pos" : " amount-neg"}`}>
                  {formatMinor(t.amount_minor, t.currency)}
                </td>
                <td className="money">
                  {t.balance_after_minor != null ? formatMinor(t.balance_after_minor, t.currency) : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Panel>
  );
}