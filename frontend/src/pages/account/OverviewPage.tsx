import { useEffect, useState } from "react";
import { Alert, Button, Panel, Tag } from "../../components/ui";
import { formatDateTime } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { AccountData } from "../../lib/types";
import { useAuth } from "../../context/AuthContext";

export function AccountOverviewPage() {
  const { user, refresh } = useAuth();
  const [data, setData] = useState<AccountData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.account
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
        <span className="muted">Loading account</span>
      </div>
    );
  }

  if (error) {
    return (
      <Alert tone="error">
        {error}
      </Alert>
    );
  }

  if (!data) return null;

  return (
    <div className="stack-lg">
      {data.verification.email_verified ? null : (
        <Alert tone="warn">
          Your email address is not verified. Check your inbox for the verification link or use the
          &ldquo;Verify email&rdquo; section below.
        </Alert>
      )}
      <div className="grid-2">
        <Panel title="Account status">
          <dl className="kv">
            <div className="kv-row">
              <dt>Email</dt>
              <dd>{data.user.email}</dd>
            </div>
            <div className="kv-row">
              <dt>Status</dt>
              <dd>{data.user.status}</dd>
            </div>
            <div className="kv-row">
              <dt>Role</dt>
              <dd>{data.user.role ?? "player"}</dd>
            </div>
            <div className="kv-row">
              <dt>Email verified</dt>
              <dd>{data.verification.email_verified ? "Yes" : "No"}</dd>
            </div>
            <div className="kv-row">
              <dt>Last sign-in</dt>
              <dd>{formatDateTime(data.user.last_sign_in_at)}</dd>
            </div>
            <div className="kv-row">
              <dt>Member since</dt>
              <dd>{formatDateTime(data.user.created_at)}</dd>
            </div>
          </dl>
          {!data.verification.email_verified ? (
            <Button onClick={() => void api.auth.resendVerification().then(() => refresh())}>
              Resend verification email
            </Button>
          ) : null}
        </Panel>
        <Panel title="Wallets" sub="Balances reflect the append-only ledger and are never client-authoritative.">
          {data.wallets.length === 0 ? (
            <p className="muted mb-0">No wallets are provisioned for this account yet.</p>
          ) : (
            <dl className="kv">
              {data.wallets.map((w) => (
                <div className="kv-row" key={w.id}>
                  <dt>
                    {w.kind} · {w.currency}
                    {w.real_money ? " · real money" : ""}
                  </dt>
                  <dd className="money">{w.balance} {w.currency}</dd>
                </div>
              ))}
            </dl>
          )}
        </Panel>
      </div>
      <Panel title="Active restrictions" sub="Server-side responsible gaming restrictions that currently apply.">
        {data.restrictions.length === 0 ? (
          <p className="muted mb-0">No active restrictions.</p>
        ) : (
          <div className="stack">
            {data.restrictions.map((r) => (
              <div key={r.id} className="row row--between">
                <div>
                  <strong>{r.kind}</strong>
                  <p className="muted mb-0">{r.reason || "No reason provided"}</p>
                </div>
                <div className="row">
                  <Tag tone={r.open_ended ? "gold" : "dim"}>
                    {r.open_ended ? "Open-ended" : `Ends ${formatDateTime(r.ends_at)}`}
                  </Tag>
                  <Tag tone="dim">Since {formatDateTime(r.starts_at)}</Tag>
                </div>
              </div>
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
}