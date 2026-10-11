import { useCallback, useEffect, useState } from "react";
import { Alert, Button, Eyebrow, Panel, Spinner } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";
import { money } from "../lib/format";
import type { GameAdminConfig, RtpReport } from "../lib/gameTypes";

// The operator-facing game console. Everything here is a real setting the
// server validates, audits and applies immediately — nothing is cosmetic.

interface Field {
  key: string;
  label: string;
  hint: string;
  kind: "number" | "boolean";
  step?: number;
  suffix?: string;
}

const FIELDS: Field[] = [
  {
    key: "user_rtp_percent",
    label: "Return to player",
    hint: "Share of every wager returned to the player over the long run. The rest is the house edge.",
    kind: "number",
    step: 0.01,
    suffix: "%",
  },
  {
    key: "bonus_trigger_prob_percent",
    label: "Bonus trigger chance",
    hint: "Weight applied to the bonus roll on a paying spin. Scatter symbols remain an independent path in.",
    kind: "number",
    step: 0.01,
    suffix: "%",
  },
  {
    key: "buy_bonus_enabled",
    label: "Buy bonus",
    hint: "Allow players to purchase the feature directly at the configured cost.",
    kind: "boolean",
  },
  {
    key: "buy_bonus_cost_multiple",
    label: "Buy bonus cost",
    hint: "How many times the base bet a purchased bonus costs.",
    kind: "number",
    step: 1,
    suffix: "x bet",
  },
  {
    key: "min_bet_minor",
    label: "Minimum bet",
    hint: "Smallest stake accepted, in minor units of the play-money currency.",
    kind: "number",
    step: 1,
  },
  {
    key: "max_bet_minor",
    label: "Maximum bet",
    hint: "Largest stake accepted, in minor units.",
    kind: "number",
    step: 1,
  },
  {
    key: "default_bet_minor",
    label: "Default bet",
    hint: "Stake pre-filled when a player opens a title.",
    kind: "number",
    step: 1,
  },
  {
    key: "auto_play_max_spins",
    label: "Auto-play limit",
    hint: "Maximum number of spins offered to auto play.",
    kind: "number",
    step: 1,
  },
  {
    key: "allow_free_spins",
    label: "Free spins",
    hint: "Master switch for the free-spin feature.",
    kind: "boolean",
  },
];

export default function AdminGamesPage() {
  const [data, setData] = useState<GameAdminConfig | null>(null);
  const [draft, setDraft] = useState<Record<string, number | boolean>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [rtp, setRtp] = useState<RtpReport | null>(null);
  const [rtpLoading, setRtpLoading] = useState(false);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    api.games_admin
      .config()
      .then((res) => {
        setData(res);
        setDraft({ ...res.config });
      })
      .catch((e: unknown) => setError(apiErrorMessage(e)))
      .finally(() => setLoading(false));
  }, []);

  useEffect(load, [load]);

  const dirty = useMemoDirty(data?.config, draft);

  const save = async () => {
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const res = await api.games_admin.updateConfig(draft);
      setData(res);
      setDraft({ ...res.config });
      setNotice("Saved. The change applies to the very next spin.");
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  const measure = async () => {
    setRtpLoading(true);
    setError(null);
    try {
      setRtp(await api.games_admin.rtp(20_000));
    } catch (e: unknown) {
      setError(apiErrorMessage(e));
    } finally {
      setRtpLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="stack">
        <Spinner label="Loading game configuration" />
      </div>
    );
  }

  return (
    <div className="stack-lg">
      <header>
        <Eyebrow>Administration</Eyebrow>
        <h1 className="hero-title" style={{ fontSize: "clamp(1.8rem, 5vw, 2.6rem)" }}>
          Game maths
        </h1>
        <p className="muted">
          Payout, feature and stake settings for every title. Changes are validated by the server,
          written to the database and recorded in the audit log.
        </p>
      </header>

      {error ? <Alert tone="error">{error}</Alert> : null}
      {notice ? <Alert tone="success">{notice}</Alert> : null}

      {data && (data.overrides.buy_bonus_disabled_by_env || data.overrides.free_spins_disabled_by_env) ? (
        <Alert tone="warn">
          An environment kill switch is active:{" "}
          {[
            data.overrides.buy_bonus_disabled_by_env ? "buy bonus disabled" : null,
            data.overrides.free_spins_disabled_by_env ? "free spins disabled" : null,
          ]
            .filter(Boolean)
            .join(", ")}
          . Environment variables override the settings on this screen.
        </Alert>
      ) : null}

      <Panel title="Registered titles">
        <table className="table">
          <thead>
            <tr>
              <th scope="col">Title</th>
              <th scope="col">Status</th>
              <th scope="col">Paylines</th>
              <th scope="col">Free spins at 3 / 4 / 5 scatters</th>
            </tr>
          </thead>
          <tbody>
            {data?.games.map((g) => (
              <tr key={g.id}>
                <th scope="row">{g.name}</th>
                <td>
                  <span className={`pill pill--${g.playable ? "ok" : "off"}`}>{g.status}</span>
                </td>
                <td>{g.paylines ?? "—"}</td>
                <td>
                  {g.free_spin_awards
                    ? [3, 4, 5].map((n) => `${n}: ${g.free_spin_awards?.[String(n)] ?? "—"}`).join("  ·  ")
                    : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Panel>

      <Panel title="Settings">
        <div className="stack">
          {FIELDS.map((field) => {
            const limits = data?.limits?.[field.key];
            const value = draft[field.key];

            return (
              <div className="setting" key={field.key}>
                <div className="setting__text">
                  <label className="setting__label" htmlFor={`cfg-${field.key}`}>
                    {field.label}
                    {field.suffix ? <span className="setting__suffix"> ({field.suffix})</span> : null}
                  </label>
                  <p className="setting__hint">{field.hint}</p>
                  {limits ? (
                    <p className="setting__range">
                      Allowed {limits[0]} – {limits[1]}
                    </p>
                  ) : null}
                </div>

                {field.kind === "boolean" ? (
                  <label className="switch">
                    <input
                      id={`cfg-${field.key}`}
                      type="checkbox"
                      checked={Boolean(value)}
                      data-testid={`cfg-${field.key}`}
                      onChange={(e) =>
                        setDraft((d) => ({ ...d, [field.key]: e.target.checked }))
                      }
                    />
                    <span className="switch__track" aria-hidden="true" />
                    <span className="switch__label">{value ? "On" : "Off"}</span>
                  </label>
                ) : (
                  <input
                    id={`cfg-${field.key}`}
                    className="input input--number"
                    type="number"
                    step={field.step}
                    min={limits?.[0]}
                    max={limits?.[1]}
                    value={typeof value === "number" ? value : ""}
                    data-testid={`cfg-${field.key}`}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, [field.key]: Number(e.target.value) }))
                    }
                  />
                )}
              </div>
            );
          })}
        </div>

        <div className="row mt-3">
          <Button variant="primary" disabled={!dirty || saving} loading={saving} onClick={() => void save()} data-testid="save-config">
            Save settings
          </Button>
          <Button variant="ghost" disabled={!dirty || saving} onClick={() => data && setDraft({ ...data.config })}>
            Discard changes
          </Button>
        </div>
      </Panel>

      <Panel title="Measured return to player">
        <p className="muted">
          Runs the actual game maths through a Monte Carlo simulation and reports what came back.
          The figure includes the confidence interval, so a noisy sample is visible rather than
          presented as fact.
        </p>

        <div className="row mt-2">
          <Button variant="ghost" loading={rtpLoading} onClick={() => void measure()} data-testid="measure-rtp">
            {rtp ? "Re-run simulation" : "Run simulation"}
          </Button>
          {rtp ? (
            <span className="muted small">
              {rtp.spins.toLocaleString("en-GB")} spins per title · target {rtp.target_percent}%
            </span>
          ) : null}
        </div>

        {rtp ? (
          <table className="table mt-2">
            <thead>
              <tr>
                <th scope="col">Title</th>
                <th scope="col">Measured RTP</th>
                <th scope="col">± 95% CI</th>
                <th scope="col">Payout scale</th>
              </tr>
            </thead>
            <tbody>
              {rtp.games.map((g) => (
                <tr key={g.slug}>
                  <th scope="row">{g.slug}</th>
                  <td>
                    <strong>{g.rtp_percent.toFixed(3)}%</strong>
                  </td>
                  <td className="muted">±{g.margin_error_percent.toFixed(3)}%</td>
                  <td className="muted">{g.scale.toFixed(5)}x</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
      </Panel>

      <Panel title="Balance an account">
        <p className="muted">
          Use the wallet adjustment endpoint to credit play money for testing. Every adjustment is
          written to the append-only ledger.
        </p>
        <p className="muted small">
          Current wallet view:{" "}
          <Link to="/admin/wallets" className="link">
            open the wallets screen
          </Link>
          {" · "}
          {money(0, "VCR")} reference format
        </p>
      </Panel>
    </div>
  );
}

/** True when the draft differs from the persisted config. */
function useMemoDirty(
  saved: Record<string, number | boolean> | undefined,
  draft: Record<string, number | boolean>,
): boolean {
  if (!saved) return false;
  return Object.keys(draft).some((key) => draft[key] !== saved[key]);
}

function Link({ to, className, children }: { to: string; className?: string; children: React.ReactNode }) {
  return (
    <a href={to} className={className}>
      {children}
    </a>
  );
}