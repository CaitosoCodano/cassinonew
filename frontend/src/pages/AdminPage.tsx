import { useEffect, useState } from "react";
import { Alert, Panel, Tag, Button } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";
import type { SystemInfo, AuditEvent } from "../lib/types";
import { formatDateTime } from "../lib/format";

export default function AdminPage() {
  const [system, setSystem] = useState<SystemInfo | null>(null);
  const [audit, setAudit] = useState<AuditEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, a] = await Promise.all([api.admin.system(), api.admin.audit()]);
      setSystem(s);
      setAudit(a.data);
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  if (loading) {
    return (
      <div>
        <PageHeader title="Administration" eyebrow="Admin" />
        <div className="row">
          <span className="spinner" aria-hidden="true" />
          <span className="muted">Loading system state</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <PageHeader title="Administration" eyebrow="Admin" />
        <Alert tone="error">{error}</Alert>
      </div>
    );
  }

  if (!system) return null;

  return (
    <div className="stack-lg">
      <PageHeader
        title="Administration"
        eyebrow="Admin"
        lead="Server-side configuration, registry and real measurements (no fabricated metrics)."
        actions={<Button onClick={() => void load()}>Refresh</Button>}
      />
      <div className="grid-3">
        <Panel title="Users">
          <dl className="kv">
            <div className="kv-row">
              <dt>Total</dt>
              <dd>{system.counts.users}</dd>
            </div>
            <div className="kv-row">
              <dt>Active</dt>
              <dd>{system.counts.active_users}</dd>
            </div>
            <div className="kv-row">
              <dt>Pending</dt>
              <dd>{system.counts.pending_users}</dd>
            </div>
          </dl>
        </Panel>
        <Panel title="Games &amp; providers">
          <dl className="kv">
            <div className="kv-row">
              <dt>Providers</dt>
              <dd>{system.counts.game_providers}</dd>
            </div>
            <div className="kv-row">
              <dt>Active providers</dt>
              <dd>{system.counts.active_game_providers}</dd>
            </div>
            <div className="kv-row">
              <dt>Games</dt>
              <dd>{system.counts.games}</dd>
            </div>
            <div className="kv-row">
              <dt>Active games</dt>
              <dd>{system.counts.active_games}</dd>
            </div>
          </dl>
        </Panel>
        <Panel title="Transactions &amp; support">
          <dl className="kv">
            <div className="kv-row">
              <dt>Transactions</dt>
              <dd>{system.counts.transactions}</dd>
            </div>
            <div className="kv-row">
              <dt>Ledger entries</dt>
              <dd>{system.counts.ledger_entries}</dd>
            </div>
            <div className="kv-row">
              <dt>Open support</dt>
              <dd>{system.counts.open_support_requests}</dd>
            </div>
          </dl>
        </Panel>
      </div>
      <Panel title="Integration registry" sub="Registered adapters are loaded by the backend; availability follows provider status.">
        {system.integration_status.length === 0 ? (
          <p className="muted mb-0">No providers registered. No adapters shipped with this foundation.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Slug</th>
                <th>Status</th>
                <th>Health</th>
                <th>Adapter configured</th>
                <th>Version</th>
                <th>Last health check</th>
              </tr>
            </thead>
            <tbody>
              {system.integration_status.map((i) => (
                <tr key={i.slug}>
                  <td>{i.slug}</td>
                  <td>{i.status}</td>
                  <td>{i.health_status}</td>
                  <td>{i.adapter_configured ? "Yes" : "No"}</td>
                  <td>{i.integration_version ?? "—"}</td>
                  <td>{formatDateTime(i.last_health_check_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      <Panel title="Platform state" sub="Real configuration snapshot.">
        <dl className="kv">
          <div className="kv-row">
            <dt>Environment</dt>
            <dd>{system.environment}</dd>
          </div>
          <div className="kv-row">
            <dt>DB adapter</dt>
            <dd>{system.database.adapter}</dd>
          </div>
          <div className="kv-row">
            <dt>DB connected</dt>
            <dd>{system.database.connected ? "Yes" : "No"}</dd>
          </div>
          <div className="kv-row">
            <dt>Cache store</dt>
            <dd>{system.cache_store}</dd>
          </div>
          <div className="kv-row">
            <dt>Job adapter</dt>
            <dd>{system.job_adapter}</dd>
          </div>
          <div className="kv-row">
            <dt>Redis configured</dt>
            <dd>{system.redis_configured ? "Yes" : "No"}</dd>
          </div>
          <div className="kv-row">
            <dt>Real money enabled</dt>
            <dd>{system.real_money_enabled ? "Yes" : "No"}</dd>
          </div>
          <div className="kv-row">
            <dt>Registered adapters</dt>
            <dd>{system.registered_adapters.join(", ") || "none"}</dd>
          </div>
        </dl>
      </Panel>
      <Panel title="Recent audit events" sub="Top 20 most recent audit entries for this deployment.">
        {audit.length === 0 ? (
          <p className="muted mb-0">No audit events.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Action</th>
                <th>Actor</th>
                <th>Target</th>
                <th>IP</th>
              </tr>
            </thead>
            <tbody>
              {audit.slice(0, 20).map((a) => (
                <tr key={a.id}>
                  <td>{formatDateTime(a.created_at)}</td>
                  <td>{a.action}</td>
                  <td className="mono">actor:{a.metadata && typeof a.metadata === "object" && a.metadata && "admin_id" in a.metadata ? (a.metadata as any).admin_id : "—"}</td>
                  <td>{a.auditable_type ? `${a.auditable_type}#${a.auditable_id ?? ""}` : "—"}</td>
                  <td className="mono">{a.ip_address ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}