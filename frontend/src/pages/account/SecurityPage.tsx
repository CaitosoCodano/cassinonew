import { useState } from "react";
import { Alert, Button, Field, Input, Panel } from "../../components/ui";
import { api, apiErrorMessage } from "../../lib/api";

export function AccountSecurityPage() {
  const [current, setCurrent] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [loading, setLoading] = useState(false);
  const [ok, setOk] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setOk(null);
    if (password !== passwordConfirmation) {
      setError("Passwords do not match.");
      return;
    }
    setLoading(true);
    try {
      const r = await api.account.changePassword({
        current_password: current,
        password,
        password_confirmation: passwordConfirmation,
      });
      setOk(r.message);
      setCurrent("");
      setPassword("");
      setPasswordConfirmation("");
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Could not change password.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="stack-lg">
      <Panel title="Change password" sub="Changing your password revokes all other active sessions. Your current session remains active.">
        {error ? <Alert tone="error">{error}</Alert> : null}
        {ok ? <Alert tone="success">{ok}</Alert> : null}
        <form onSubmit={handleSubmit} noValidate>
          <Field label="Current password" htmlFor="current">
            <Input
              id="current"
              type="password"
              autoComplete="current-password"
              required
              value={current}
              onChange={(e) => setCurrent(e.target.value)}
            />
          </Field>
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
          <Button variant="primary" type="submit" loading={loading}>
            Update password
          </Button>
        </form>
      </Panel>
      <Panel title="Account security posture" sub="Authentication, session rotation and CSRF protection are enforced server-side.">
        <ul className="muted">
          <li>Passwords are stored as salted hashes.</li>
          <li>Session cookies are HttpOnly, signed and encrypted.</li>
          <li>State-changing requests require a CSRF token issued by the backend.</li>
          <li>Login, logout and password changes invalidate other sessions.</li>
        </ul>
      </Panel>
    </div>
  );
}