import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Alert, Button, Checkbox, Field, Input, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";
import { resetCsrf } from "../lib/api";
import { useAuth } from "../context/AuthContext";

export default function RegisterPage() {
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [marketing, setMarketing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password !== passwordConfirmation) {
      setError("Passwords do not match.");
      return;
    }
    setLoading(true);
    try {
      await api.auth.register({
        email,
        password,
        password_confirmation: passwordConfirmation,
        marketing_opt_in: marketing,
      });
      // Registration succeeds; session may not exist yet, but the cookie should
      // have been issued. Re-fetch session and refetch CSRF.
      resetCsrf();
      await refresh();
      navigate("/verify-email", { state: { email } });
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Could not create your account.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="Create account"
        eyebrow="Account"
        lead="Register with a real email address to receive your verification link."
      />
      {error ? (
        <Alert tone="error" className="mb-2">
          {error}
        </Alert>
      ) : null}
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
          <div className="grid-2">
            <Field label="Password" htmlFor="password">
              <Input
                id="password"
                type="password"
                autoComplete="new-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Field>
            <Field label="Confirm password" htmlFor="password_confirmation">
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
          <Checkbox
            label="Opt-in to marketing (optional)"
            checked={marketing}
            onChange={(e) => setMarketing(e.target.checked)}
          />
          <p className="dim mt-1">
            Passwords must meet the minimum complexity enforced by the platform. A new account is
            credited with welcome play money so you can try the games straight away.
          </p>
          <div className="row row--between mt-2">
            <Link to="/login">Already have an account?</Link>
            <Button variant="primary" type="submit" loading={loading}>
              Register
            </Button>
          </div>
        </form>
      </Panel>
    </div>
  );
}