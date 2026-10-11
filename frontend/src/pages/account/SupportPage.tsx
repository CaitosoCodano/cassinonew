import { useEffect, useState } from "react";
import { Alert, Button, Field, Input, Panel, Select, Textarea } from "../../components/ui";
import { formatDateTime } from "../../lib/format";
import { api, apiErrorMessage } from "../../lib/api";
import type { SupportRequest } from "../../lib/types";

export function AccountSupportPage() {
  const [tickets, setTickets] = useState<SupportRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("");
  const [category, setCategory] = useState("general");
  const [sending, setSending] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.support.list();
      setTickets(res.data);
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setOk(null);
    if (!subject.trim() || !message.trim()) {
      setError("Subject and message are required.");
      return;
    }
    setSending(true);
    try {
      await api.support.create({ subject: subject.trim(), message: message.trim(), category });
      setOk("Support request submitted.");
      setSubject("");
      setMessage("");
      await load();
    } catch (err: unknown) {
      setError(apiErrorMessage(err) || "Could not submit support request.");
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="stack-lg">
      <Panel title="Submit a request" sub="Support requests can be opened by guests or signed-in users.">
        {error ? <Alert tone="error">{error}</Alert> : null}
        {ok ? <Alert tone="success">{ok}</Alert> : null}
        <form onSubmit={submit} noValidate>
          <Field label="Subject" htmlFor="subject">
            <Input
              id="subject"
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              required
            />
          </Field>
          <Field label="Category" htmlFor="category">
            <Select id="category" value={category} onChange={(e) => setCategory(e.target.value)}>
              <option value="general">General</option>
              <option value="account">Account</option>
              <option value="billing">Billing</option>
              <option value="technical">Technical</option>
              <option value="responsible_gaming">Responsible gaming</option>
            </Select>
          </Field>
          <Field label="Message" htmlFor="message">
            <Textarea
              id="message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              required
            />
          </Field>
          <Button variant="primary" type="submit" loading={sending}>
            Submit request
          </Button>
        </form>
      </Panel>
      <Panel title="My requests" sub="Past support requests for this account.">
        {loading ? (
          <div className="row">
            <span className="spinner" aria-hidden="true" />
            <span className="muted">Loading requests</span>
          </div>
        ) : tickets.length === 0 ? (
          <p className="muted mb-0">No requests yet.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Subject</th>
                <th>Category</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Created</th>
                <th>Updated</th>
              </tr>
            </thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.id}>
                  <td>#{t.id}</td>
                  <td>{t.subject}</td>
                  <td>{t.category}</td>
                  <td>{t.status}</td>
                  <td>{t.priority}</td>
                  <td>{formatDateTime(t.created_at)}</td>
                  <td>{formatDateTime(t.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}