import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Alert, Button, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";
import { useAuth } from "../context/AuthContext";

export default function VerifyEmailPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const token = params.get("token");
  const [state, setState] = useState<"idle" | "verifying" | "ok" | "error">("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [resending, setResending] = useState(false);

  useEffect(() => {
    if (!token) {
      setState("idle");
      return;
    }
    let cancelled = false;
    setState("verifying");
    api.auth
      .verifyEmail(token)
      .then(() => {
        if (cancelled) return;
        setState("ok");
        void refresh();
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setState("error");
        setMessage(apiErrorMessage(e));
      });
    return () => {
      cancelled = true;
    };
  }, [token, refresh]);

  const handleResend = async () => {
    setResending(true);
    setMessage(null);
    try {
      const r = await api.auth.resendVerification();
      setMessage(r.message);
    } catch (e: unknown) {
      setMessage(apiErrorMessage(e) || "Could not resend verification email.");
    } finally {
      setResending(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="Verify your email"
        eyebrow="Account"
        lead="Verification links are single-use and expire after 24 hours."
      />
      {state === "verifying" ? (
        <div className="row">
          <span className="spinner" aria-hidden="true" />
          <span className="muted">Verifying your email address…</span>
        </div>
      ) : null}
      {state === "ok" ? (
        <Alert tone="success" className="mb-2">
          Your email has been verified. Your account is ready to use.
        </Alert>
      ) : null}
      {state === "error" ? (
        <Alert tone="error" className="mb-2">
          {message ?? "The verification link is invalid or has expired."}
        </Alert>
      ) : null}
      {!token && state === "idle" ? (
        <Alert tone="info" className="mb-2">
          Check your email for a verification link (subject: &ldquo;Verify your Luminara account&rdquo;).
          If you’re running the backend locally, the email is written to <code>backend/tmp/mails</code>.
        </Alert>
      ) : null}
      {message && state !== "error" && state !== "ok" ? (
        <Alert tone="info" className="mb-2">
          {message}
        </Alert>
      ) : null}
      <Panel>
        <div className="row row--between">
          <div className="row">
            <Link className="btn" to="/account">
              Go to my account
            </Link>
            <Button onClick={handleResend} loading={resending}>
              Resend verification email
            </Button>
          </div>
        </div>
      </Panel>
    </div>
  );
}