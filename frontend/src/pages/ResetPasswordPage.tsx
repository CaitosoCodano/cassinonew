import { useEffect, useState } from "react";
import { Link, useSearchParams, useNavigate } from "react-router-dom";
import { Alert, Button, Field, Input, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";

export default function ResetPasswordPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const token = params.get("token") ?? "";
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  useEffect(() => {
    if (!token) {
      setError("Missing reset token. The link in your email may be incomplete.");
    } else {
      setError(null);
    }
  }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) return;
    if (password !== passwordConfirmation) {
      setError("Passwords do not match.");
      return;
    }
    setError(null);
    setLoading(true);
    try {
      await api.auth.resetPassword({ token, password, password_confirmation: passwordConfirmation });
      setOk(true);
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Could not reset your password.");
    } finally {
      setLoading(false);
    }
  };

  if (ok) {
    return (
      <div>
        <PageHeader
          title="Password reset"
          eyebrow="Account"
          lead="Your password has been reset successfully."
        />
        <Alert tone="success" className="mb-2">
          You can now sign in with your new password.
        </Alert>
        <Link className="btn btn--primary" to="/login">
          Sign in
        </Link>
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        title="Set new password"
        eyebrow="Account"
        lead="Enter and confirm your new password."
      />
      {error ? (
        <Alert tone="error" className="mb-2">
          {error}
        </Alert>
      ) : null}
      <Panel>
        <form onSubmit={handleSubmit} noValidate>
          <div className="grid-2">
            <Field label="New password" htmlFor="password">
              <Input
                id="password"
                type="password"
                autoComplete="new-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Field>
            <Field label="Confirm new password" htmlFor="password_confirmation">
              <Input
                id="password_confirmation"
                type="password"
                autoComplete="new-password"
                required
                value={passwordConfirmation}
                onChange={(e) => setPasswordConfirmation(e.target.value)}
              />
            </Field>
          </div>
          <div className="row row--between">
            <Link to="/login">Back to sign in</Link>
            <Button variant="primary" type="submit" loading={loading} disabled={!token}>
              Reset password
            </Button>
          </div>
        </form>
      </Panel>
    </div>
  );
}