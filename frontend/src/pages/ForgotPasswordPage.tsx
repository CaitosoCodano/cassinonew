import { useState } from "react";
import { Link } from "react-router-dom";
import { Alert, Button, Field, Input, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await api.auth.forgotPassword(email);
      setDone(true);
    } catch (err: unknown) {
      // The backend always returns 202 even if the account doesn't exist.
      // Surface the real message if available, but still indicate success.
      setDone(true);
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="Forgot password"
        eyebrow="Account"
        lead="Enter your email address — if an account exists, a reset link will be sent."
      />
      {error && !done ? (
        <Alert tone="error" className="mb-2">
          {error}
        </Alert>
      ) : null}
      {done ? (
        <Alert tone="success" className="mb-2">
          If an account exists for that email, a reset link has been sent. Check your inbox (or the
          local development mail directory if running the backend in dev).
        </Alert>
      ) : null}
      {!done ? (
        <Panel>
          <form onSubmit={handleSubmit} noValidate>
            <Field label="Email address" htmlFor="email">
              <Input
                id="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </Field>
            <div className="row row--between">
              <Link to="/login">Back to sign in</Link>
              <Button variant="primary" type="submit" loading={loading}>
                Send reset link
              </Button>
            </div>
          </form>
        </Panel>
      ) : (
        <div className="row">
          <Link className="btn" to="/login">
            Back to sign in
          </Link>
        </div>
      )}
    </div>
  );
}