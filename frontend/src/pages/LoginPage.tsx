import { useState } from "react";
import { useNavigate, useLocation, Link } from "react-router-dom";
import { Alert, Button, Field, Input, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";
import { useAuth } from "../context/AuthContext";
import { apiErrorMessage } from "../lib/api";

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const redirectTo = (location.state as { from?: string } | null)?.from ?? "/account";

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(email, password);
      navigate(redirectTo, { replace: true });
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Invalid email or password.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="Sign in"
        eyebrow="Account"
        lead="Enter your email and password to access your Luminara account."
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
          <Field label="Password" htmlFor="password" hint="Use the password you set at registration.">
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>
          <div className="row row--between">
            <Link to="/forgot-password">Forgot password</Link>
            <Button variant="primary" type="submit" loading={loading}>
              Sign in
            </Button>
          </div>
          <p className="muted mt-2 mb-0">
            No account yet? <Link to="/register">Create one</Link>
          </p>
        </form>
      </Panel>
    </div>
  );
}