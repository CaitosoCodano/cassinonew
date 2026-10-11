import { useEffect, useState } from "react";
import { Alert, Button, Panel, Tag } from "../../components/ui";
import { formatDateTime, timeAgo } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { SessionInfo } from "../../lib/types";

export function AccountSessionsPage() {
  const [sessions, setSessions] = useState<SessionInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [revoking, setRevoking] = useState<number | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.account.sessions();
      setSessions(res.data);
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const revoke = async (id: number) => {
    setRevoking(id);
    try {
      await api.account.revokeSession(id);
      await load();
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setRevoking(null);
    }
  };

  if (loading) {
    return (
      <div className="row">
        <span className="spinner" aria-hidden="true" />
        <span className="muted">Loading sessions</span>
      </div>
    );
  }

  if (error) return <Alert tone="error">{error}</Alert>;

  return (
    <Panel title="Active sessions" sub="Revoke any device you no longer recognise. Revoking the current session will sign you out.">
      {sessions.length === 0 ? (
        <p className="muted mb-0">No sessions found.</p>
      ) : (
        <div className="stack">
          {sessions.map((s) => (
            <div key={s.id} className="panel panel--inset">
              <div className="row row--between">
                <div>
                  <h4 className="mb-0">{s.device ?? "Unknown device"}</h4>
                  <p className="muted mb-0">IP: {s.ip_address ?? "—"}</p>
                </div>
                <div className="row">
                  {s.current ? <Tag tone="gold">Current</Tag> : null}
                  {s.revoked ? <Tag tone="danger">Revoked</Tag> : <Tag tone="success">Active</Tag>}
                  {!s.revoked ? (
                    <Button size="sm" onClick={() => void revoke(s.id)} loading={revoking === s.id}>
                      Revoke
                    </Button>
                  ) : null}
                </div>
              </div>
              <p className="dim mt-1 mb-0">
                Last seen {timeAgo(s.last_seen_at)} · Signed in {formatDateTime(s.created_at)} · Expires {formatDateTime(s.expires_at)}
              </p>
            </div>
          ))}
        </div>
      )}
      <div className="mt-2">
        <Button onClick={() => void api.auth.logoutAll()}>Sign out of all devices</Button>
      </div>
    </Panel>
  );
}