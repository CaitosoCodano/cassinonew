import { useEffect, useState } from "react";
import { Alert, Button, Field, Input, Panel, Tag } from "../../components/ui";
import { formatDateTime } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { ResponsibleGamingLimit, AccountRestriction } from "../../lib/types";

export function AccountResponsibleGamingPage() {
  const [limits, setLimits] = useState<ResponsibleGamingLimit[]>([]);
  const [restrictions, setRestrictions] = useState<AccountRestriction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [days, setDays] = useState("7");
  const [reason, setReason] = useState("");
  const [excluding, setExcluding] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const [l, r] = await Promise.all([api.rg.limits(), api.rg.restrictions()]);
      setLimits(l);
      setRestrictions(r.data);
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const selfExclude = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setOk(null);
    const d = Number(days);
    if (Number.isNaN(d) || d < 1) {
      setError("Duration must be at least 1 day.");
      return;
    }
    setExcluding(true);
    try {
      await api.rg.selfExclude({ duration_days: d, reason: reason || undefined });
      setOk("Self-exclusion requested. Your session has been ended and the restriction is active.");
      setDays("7");
      setReason("");
      await load();
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Could not set self-exclusion.");
    } finally {
      setExcluding(false);
    }
  };

  if (loading) {
    return (
      <div className="row">
        <span className="spinner" aria-hidden="true" />
        <span className="muted">Loading responsible gaming settings</span>
      </div>
    );
  }

  if (error) return <Alert tone="error">{error}</Alert>;

  return (
    <div className="stack-lg">
      <Panel title="Responsible gaming limits" sub="Limits are real server-side controls. If you have an active self-exclusion, account activity is restricted.">
        {limits.length === 0 ? (
          <p className="muted mb-0">No limits are set on this account.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Kind</th>
                <th>Period</th>
                <th>Amount</th>
                <th>Active</th>
                <th>Effective from</th>
                <th>Effective until</th>
              </tr>
            </thead>
            <tbody>
              {limits.map((l) => (
                <tr key={l.id}>
                  <td>{l.kind}</td>
                  <td>{l.period}</td>
                  <td className="money">{l.amount} {l.kind.includes("deposit") ? "EUR" : ""}</td>
                  <td>{l.active ? "Yes" : "No"}</td>
                  <td>{formatDateTime(l.effective_from)}</td>
                  <td>{l.effective_until ? formatDateTime(l.effective_until) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      <Panel title="Restrictions" sub="Account restrictions are applied server-side and cannot be bypassed from the client.">
        {restrictions.length === 0 ? (
          <p className="muted mb-0">No restrictions recorded.</p>
        ) : (
          <div className="stack">
            {restrictions.map((r) => (
              <div key={r.id} className="panel panel--inset">
                <div className="row row--between">
                  <div>
                    <strong>{r.kind}</strong>
                    <p className="muted mb-0">{r.reason || "No reason"}</p>
                  </div>
                  <div className="row">
                    <Tag tone={r.status === "active" ? "danger" : "dim"}>{r.status}</Tag>
                    <Tag tone="dim">From {formatDateTime(r.starts_at)}</Tag>
                    {r.ends_at ? <Tag tone="dim">Until {formatDateTime(r.ends_at)}</Tag> : null}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Panel>
      <Panel title="Self-exclusion" sub="Self-exclusion prevents access and is permanent in effect until the chosen duration elapses.">
        {ok ? <Alert tone="success">{ok}</Alert> : null}
        <form onSubmit={selfExclude} noValidate>
          <div className="grid-2">
            <Field label="Duration (days)" htmlFor="days" hint="Minimum 1 day">
              <Input
                id="days"
                type="number"
                min={1}
                value={days}
                onChange={(e) => setDays(e.target.value)}
              />
            </Field>
            <Field label="Reason (optional)" htmlFor="reason">
              <Input
                id="reason"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
            </Field>
          </div>
          <p className="muted">
            Submitting self-exclusion will revoke all your sessions and end your current session. The
            restriction is recorded server-side.
          </p>
          <Button variant="primary" type="submit" loading={excluding}>
            Apply self-exclusion
          </Button>
        </form>
      </Panel>
    </div>
  );
}