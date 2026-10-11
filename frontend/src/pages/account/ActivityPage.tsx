import { useEffect, useState } from "react";
import { Alert, Button, Field, Input, Panel } from "../../components/ui";
import { formatDateTime } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { AuditEvent } from "../../lib/types";

export function AccountActivityPage() {
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.account
      .activity(1)
      .then((res) => {
        if (cancelled) return;
        setEvents(res.data);
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
        <span className="muted">Loading activity</span>
      </div>
    );
  }

  if (error) return <Alert tone="error">{error}</Alert>;

  return (
    <Panel title="Recent activity" sub="Your account activity log is retrieved directly from the server.">
      {events.length === 0 ? (
        <p className="muted mb-0">No recent activity.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Action</th>
              <th>Target</th>
              <th>IP</th>
            </tr>
          </thead>
          <tbody>
            {events.map((e) => (
              <tr key={e.id}>
                <td>{formatDateTime(e.created_at)}</td>
                <td>{e.action}</td>
                <td>{e.auditable_type ? `${e.auditable_type}#${e.auditable_id ?? ""}` : "—"}</td>
                <td className="mono">{e.ip_address ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Panel>
  );
}