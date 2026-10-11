import { useEffect, useState } from "react";
import { Alert, Button, Field, Input, Panel } from "../../components/ui";
import { api, apiErrorMessage } from "../../lib/api";
import type { Profile } from "../../lib/types";

export function AccountProfilePage() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [form, setForm] = useState({
    display_name: "",
    first_name: "",
    last_name: "",
    country_code: "",
    phone: "",
    locale: "",
    date_of_birth: "",
    marketing_opt_in: false,
  });

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api.account
      .show()
      .then((d) => {
        if (cancelled) return;
        const p = d.profile;
        setProfile(p);
        setForm({
          display_name: p?.display_name ?? "",
          first_name: p?.first_name ?? "",
          last_name: p?.last_name ?? "",
          country_code: p?.country_code ?? "",
          phone: p?.phone ?? "",
          locale: p?.locale ?? "en",
          date_of_birth: p?.date_of_birth ?? "",
          marketing_opt_in: !!p?.marketing_opt_in,
        });
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setOk(null);
    setSaving(true);
    try {
      const updated = await api.account.updateProfile({
        display_name: form.display_name || null,
        first_name: form.first_name || null,
        last_name: form.last_name || null,
        country_code: form.country_code || null,
        phone: form.phone || null,
        locale: form.locale || "en",
        date_of_birth: form.date_of_birth || null,
        marketing_opt_in: form.marketing_opt_in,
      });
      setProfile(updated);
      setOk("Profile updated.");
    } catch (err: unknown) {
      setError(apiErrorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="row">
        <span className="spinner" aria-hidden="true" />
        <span className="muted">Loading profile</span>
      </div>
    );
  }

  return (
    <Panel title="Profile details" sub="This information is not used to fabricate any real-money features. It remains editable as the platform evolves.">
      {error ? <Alert tone="error">{error}</Alert> : null}
      {ok ? <Alert tone="success">{ok}</Alert> : null}
      <form onSubmit={handleSubmit} noValidate>
        <div className="grid-2">
          <Field label="Display name" htmlFor="display_name">
            <Input
              id="display_name"
              value={form.display_name}
              onChange={(e) => setForm({ ...form, display_name: e.target.value })}
            />
          </Field>
          <Field label="Locale" htmlFor="locale">
            <Input
              id="locale"
              value={form.locale}
              onChange={(e) => setForm({ ...form, locale: e.target.value })}
            />
          </Field>
        </div>
        <div className="grid-2">
          <Field label="First name" htmlFor="first_name">
            <Input
              id="first_name"
              value={form.first_name}
              onChange={(e) => setForm({ ...form, first_name: e.target.value })}
            />
          </Field>
          <Field label="Last name" htmlFor="last_name">
            <Input
              id="last_name"
              value={form.last_name}
              onChange={(e) => setForm({ ...form, last_name: e.target.value })}
            />
          </Field>
        </div>
        <div className="grid-3">
          <Field label="Country code (ISO 2)" htmlFor="country_code">
            <Input
              id="country_code"
              placeholder="GB"
              value={form.country_code}
              onChange={(e) => setForm({ ...form, country_code: e.target.value.toUpperCase() })}
            />
          </Field>
          <Field label="Phone" htmlFor="phone">
            <Input
              id="phone"
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
            />
          </Field>
          <Field label="Date of birth" htmlFor="date_of_birth" hint="YYYY-MM-DD">
            <Input
              id="date_of_birth"
              type="date"
              value={form.date_of_birth}
              onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
            />
          </Field>
        </div>
        <div className="row">
          <Button variant="primary" type="submit" loading={saving}>
            Save profile
          </Button>
        </div>
      </form>
    </Panel>
  );
}