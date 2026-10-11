import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Alert, Button, Eyebrow, Panel } from "../components/ui";
import { SlotMachine } from "../components/SlotMachine";
import { api, apiErrorMessage } from "../lib/api";
import { money } from "../lib/format";
import type { GameMathsResponse, RoundResult, SpinSpeed } from "../lib/gameTypes";
import { SPIN_SPEEDS } from "../lib/gameTypes";

import * as sound from "../lib/sound";

// ---------------------------------------------------------------------------
// Round timeline
//
// The server resolves the whole round in one response -- paying spin, every
// free spin, the running total. The client walks that list on a clock; there is
// no follow-up request, so a bonus cannot be skipped or cut short.
// ---------------------------------------------------------------------------

type Phase = "idle" | "spinning" | "settled" | "bonus" | "complete";

interface Props {
  slug?: string;
}

const REELS = 5;

export default function GamePage({ slug }: Props) {
  const params = useParams();
  const gameSlug = slug ?? params.slug ?? "";

  const [data, setData] = useState<GameMathsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [phase, setPhase] = useState<Phase>("idle");
  const [round, setRound] = useState<RoundResult | null>(null);
  const [balance, setBalance] = useState<number | null>(null);
  /** Bumped once per spin to restart the reel animation. */
  const [spinToken, setSpinToken] = useState(0);
  /** Index of the free spin on screen; -1 when not in a bonus. */
  const [bonusIndex, setBonusIndex] = useState(-1);
  /** Music keeps playing while the player is on a game screen. */
  const [musicOn, setMusicOn] = useState(sound.readMusicPreference());

  const [bet, setBet] = useState<number | null>(null);
  const [speed, setSpeed] = useState<SpinSpeed>("normal");
  const [muted, setMuted] = useState(sound.isMuted());
  const [volume, setVolume] = useState(sound.getVolume());
  const [autoSpin, setAutoSpin] = useState(0);
  const [autoRunning, setAutoRunning] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const spinRef = useRef(0);
  // Index of the free spin currently on screen. Kept in a ref because the
  // timeline advances it from timers, and reading it during render would tear.
  const bonusRef = useRef(0);

  // --- load ---------------------------------------------------------------

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);

    api.games
      .maths(gameSlug)
      .then((res) => {
        if (!active) return;
        setData(res);
        setBet(res.config.default_bet_minor);
        setLoading(false);
      })
      .catch((e: unknown) => {
        if (!active) return;
        setError(apiErrorMessage(e));
        setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [gameSlug]);

  // The balance comes from the wallet on mount; spin responses carry the
  // authoritative figure from then on.
  useEffect(() => {
    let active = true;
    api.wallet
      .show()
      .then((wallet) => {
        if (!active) return;
        const virtual = wallet.wallets.find((w) => w.kind === "virtual");
        if (virtual) setBalance(virtual.balance_minor);
      })
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, []);

  // Warm the audio cache on first interaction with the page.
  useEffect(() => {
    const unlock = () => {
      sound.unlock();
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
    window.addEventListener("pointerdown", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);

  // --- timing -------------------------------------------------------------

  const profile = SPIN_SPEEDS[speed];

  /** Staggered start so the reels cascade left to right. */
  const timings = useMemo(
    () =>
      Array.from({ length: REELS }, (_, i) => ({
        delay: i * profile.reelStagger,
        duration: profile.reelDuration + i * profile.reelStagger * 0.45,
      })),
    [profile.reelDuration, profile.reelStagger],
  );

  const roundLength = timings[REELS - 1].delay + timings[REELS - 1].duration;

  const activeGrid = useMemo(() => {
    if (!round) return null;
    if (phase === "bonus") return round.free_spins[bonusIndex]?.grid ?? null;
    return round.grid;
  }, [round, phase, bonusIndex]);

  const activeLineWins = useMemo(() => {
    if (!round) return [];
    if (phase === "bonus") return round.free_spins[bonusIndex]?.line_wins ?? [];
    return round.line_wins;
  }, [round, phase, bonusIndex]);

  // --- reel completion ---------------------------------------------------

  const roundRef = useRef<RoundResult | null>(null);
  const phaseRef = useRef<Phase>(phase);
  phaseRef.current = phase;
  roundRef.current = round;

  const handleReelStop = useCallback((reel: number) => {
    sound.playReelStop(reel);
  }, []);

  /**
   * The reels landing is the only thing that advances the timeline.
   *
   * Driving the bonus from here rather than from a parallel timer is what
   * guarantees it plays every spin: there is exactly one clock, and it cannot
   * disagree with the animation the player is watching.
   */
  const handleSpinComplete = useCallback(() => {
    const result = roundRef.current;
    if (!result) return;

    const freeSpins = result.free_spins ?? [];
    const current = phaseRef.current;

    if (current === "spinning") {
      if (freeSpins.length > 0) {
        sound.play("scatter");
        bonusRef.current = 0;
        setBonusIndex(0);
        setPhase("bonus");
        // Start the first free spin's own reel run.
        setSpinToken((n) => n + 1);
      } else {
        if (result.win_minor === 0) setMessage("No win on this spin.");
        setPhase("complete");
      }
      return;
    }

    if (current === "bonus") {
      const spin = freeSpins[bonusRef.current];
      if (spin && spin.win_units > 0) sound.play("coin");

      const next = bonusRef.current + 1;
      if (next < freeSpins.length) {
        bonusRef.current = next;
        setBonusIndex(next);
        // Re-render so the next spin's symbols are on screen, then spin again.
        setRound({ ...result });
        setSpinToken((n) => n + 1);
      } else {
        if (result.win_minor > 0) sound.play("big-win");
        setPhase("complete");
      }
    }
  }, []);

  // Pause between bonus spins so the result can be read, without a second
  // timeline: this only fires once the reels have already landed.
  useEffect(() => {
    if (phase !== "bonus") return;
    const timer = window.setTimeout(() => {
      // Safety net: if the reels somehow never reported, step the bonus on.
      if (phaseRef.current === "bonus" && roundRef.current) handleSpinComplete();
    }, (roundLength + profile.winHold) * 2000);
    return () => window.clearTimeout(timer);
  }, [phase, handleSpinComplete, roundLength, profile.winHold]);

  // --- actions ------------------------------------------------------------

  const busy = phase === "spinning" || phase === "bonus";

  const spin = useCallback(
    async (buyBonus: boolean) => {
      if (busy || data === null || bet === null) return;

      spinRef.current += 1;
      const token = spinRef.current;

      sound.unlock();
      setMessage(null);
      setPhase("spinning");
      bonusRef.current = 0;

      sound.play("spin");

      try {
        const result = await api.games.spin(data.game.id, { bet_minor: bet, buy_bonus: buyBonus });
        if (token !== spinRef.current) return;

        setRound(result);
        setBalance(result.balance_minor);
        roundRef.current = result;

        // Bumping the token restarts the reel clock inside SlotMachine.
        setSpinToken((n) => n + 1);
      } catch (e: unknown) {
        setPhase("idle");
        setMessage(apiErrorMessage(e));
      }
    },
    [busy, data, bet],
  );

  // Auto play chains completed rounds until the counter runs out.
  useEffect(() => {
    if (!autoRunning || phase !== "complete") return;
    if (autoSpin <= 0) {
      setAutoRunning(false);
      return;
    }
    const timer = window.setTimeout(() => {
      setAutoSpin((n) => n - 1);
      void spin(false);
    }, 500);
    return () => window.clearTimeout(timer);
  }, [autoRunning, autoSpin, phase, spin]);

  const stopAuto = useCallback(() => {
    setAutoRunning(false);
    setAutoSpin(0);
  }, []);

  // --- render -------------------------------------------------------------

  // --- win presentation -------------------------------------------------------
// These live above the early returns below: a hook that only runs on the
// rendered path changes the hook count between renders and React throws.

const bonusSpins = phase === "bonus" && round ? round.free_spins.length : 0;
const bonusMultiplier = phase === "bonus" && round ? round.free_spins[bonusIndex]?.multiplier ?? 1 : 1;
const bonusRunning = phase === "bonus" && round ? round.free_spins[bonusIndex]?.win_units ?? 0 : 0;

  // The counter rolls up rather than snapping, which is what makes a win feel
  // like it was earned rather than simply appearing.
  const [winCounter, setWinCounter] = useState(0);
  const [celebrating, setCelebrating] = useState(false);

  useEffect(() => {
    const target = phase === "bonus" ? bonusRunning : round?.win_minor ?? 0;
    if (target === 0) {
      setWinCounter(0);
      return;
    }

    const duration = Math.min(1400, 350 + target / 2);
    const start = performance.now();
    let frame = 0;

    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      // Ease out so the last digits settle instead of scrolling forever.
      const eased = 1 - (1 - t) ** 3;
      setWinCounter(Math.round(target * eased));
      if (t < 1) frame = requestAnimationFrame(tick);
    };

    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [round, phase, bonusRunning]);

  // A large win gets its own full-width celebration.
  useEffect(() => {
    const threshold = (bet ?? 0) * 10;
    const qualifies = round !== null && round.win_minor > 0 && phase !== "bonus" && round.win_minor >= threshold;
    setCelebrating(qualifies);
    if (!qualifies) return;

    const timer = window.setTimeout(() => setCelebrating(false), 3200);
    return () => window.clearTimeout(timer);
  }, [round, phase, bet]);

  if (loading) {
    return (
      <div className="stack">
        <div className="loading-dot" />
        <p className="muted">Loading game</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="stack">
        <Alert tone="error">{error}</Alert>
        <Link className="btn" to="/games">
          Back to the lobby
        </Link>
      </div>
    );
  }

  if (!data) return <Alert tone="error">Game unavailable.</Alert>;

  const { maths, config } = data;
  const minBet = config.min_bet_minor;
  const maxBet = config.max_bet_minor;
  const buyCost = bet === null ? 0 : bet * config.buy_bonus_cost_multiple;
  const insufficient = balance !== null && bet !== null && balance < bet;

  return (
    <div className="game-page">
      <header className="game-page__head">
        <div>
          <Eyebrow>{maths.paylines} lines</Eyebrow>
          <h1 className="game-page__title">{maths.title}</h1>
        </div>
        <div className="game-page__balance">
          <span className="game-page__balance-label">Balance</span>
          <strong data-testid="game-balance">{money(balance ?? 0, config.currency)}</strong>
        </div>
      </header>

      {bonusSpins > 0 ? (
        <div className="game-page__bonus" role="status" data-testid="bonus-banner">
          <span className="game-page__bonus-label">
            Free spin <strong>{bonusIndex + 1}</strong> of {bonusSpins}
            {bonusRunning > 0 ? <span className="game-page__bonus-hit"> +{money(bonusRunning, config.currency)}</span> : null}
          </span>
          <span className="game-page__bonus-mult" data-testid="bonus-multiplier">
            x{bonusMultiplier}
          </span>
        </div>
      ) : null}

      <SlotMachine
        theme={maths.theme}
        grid={activeGrid}
        lineWins={activeLineWins}
        timings={timings}
        spinToken={spinToken}
        onReelStop={handleReelStop}
        onSpinComplete={handleSpinComplete}
      />

      <div className={`game-page__readout${round?.win_minor ? " game-page__readout--win" : ""}`}>
        <Readout label="Bet" value={money(bet ?? 0, config.currency)} />
        <Readout
          label={phase === "bonus" ? "Bonus win" : "Last win"}
          value={money(winCounter, config.currency)}
          testId="last-win"
        />
        {phase === "bonus" && round ? (
          <Readout label="Bonus total" value={money(round.win_minor, config.currency)} />
        ) : null}
      </div>

      {celebrating && (
        <div className="jackpot" role="status" aria-live="polite">
          <div className="jackpot__burst" aria-hidden="true" />
          <span className="jackpot__label">Big win</span>
          <strong className="jackpot__amount">{money(round?.win_minor ?? 0, config.currency)}</strong>
        </div>
      )}

      {message ? <Alert tone="info">{message}</Alert> : null}

      <Panel className="game-page__controls">
        <div className="game-page__row">
          <label className="field field--inline">
            <span className="field-label">Bet</span>
            <input
              className="input input--bet"
              type="number"
              inputMode="numeric"
              min={minBet}
              max={maxBet}
              step={minBet}
              value={bet ?? minBet}
              disabled={busy}
              onChange={(e) =>
                setBet(Math.max(minBet, Math.min(maxBet, Number(e.target.value) || minBet)))
              }
              data-testid="bet-input"
            />
          </label>

          <div className="row row--tight">
            <Button variant="ghost" size="sm" disabled={busy || (bet ?? 0) <= minBet} onClick={() => setBet(minBet)}>
              Min
            </Button>
            <Button
              variant="ghost"
              size="sm"
              disabled={busy || (bet ?? 0) <= minBet}
              onClick={() => setBet(Math.max(minBet, Math.floor((bet ?? minBet) / 2 / minBet) * minBet))}
            >
              ½
            </Button>
            <Button
              variant="ghost"
              size="sm"
              disabled={busy || (bet ?? 0) >= maxBet}
              onClick={() => setBet(Math.min(maxBet, (bet ?? minBet) * 2))}
            >
              2×
            </Button>
            <Button variant="ghost" size="sm" disabled={busy} onClick={() => setBet(maxBet)}>
              Max
            </Button>
          </div>
        </div>

        <div className="game-page__row">
          <div className="seg" role="group" aria-label="Spin speed">
            {(Object.keys(SPIN_SPEEDS) as SpinSpeed[]).map((id) => (
              <button
                key={id}
                type="button"
                className={`seg__btn${speed === id ? " seg__btn--on" : ""}`}
                aria-pressed={speed === id}
                disabled={busy}
                onClick={() => {
                  sound.unlock();
                  sound.play("button");
                  setSpeed(id);
                }}
                data-testid={`speed-${id}`}
              >
                {SPIN_SPEEDS[id].label}
              </button>
            ))}
          </div>

          <div className="sound">
            <button
              type="button"
              className={`icon-btn${muted ? " icon-btn--off" : ""}`}
              aria-pressed={muted}
              aria-label={muted ? "Unmute sound" : "Mute sound"}
              title={muted ? "Unmute" : "Mute"}
              data-testid="mute-toggle"
              onClick={() => {
                sound.unlock();
                setMuted(sound.toggleMuted());
              }}
            >
              {muted ? "\u{1F507}" : "\u{1F50A}"}
              <span className="icon-btn__text">{muted ? "Muted" : "Sound"}</span>
            </button>

            <button
              type="button"
              className={`icon-btn${musicOn ? "" : " icon-btn--off"}`}
              aria-pressed={musicOn}
              aria-label={musicOn ? "Mute music" : "Play music"}
              title={musicOn ? "Music on" : "Music off"}
              data-testid="music-toggle"
              onClick={() => {
                const next = !musicOn;
                setMusicOn(next);
                sound.persistMusicPreference(next);
                sound.unlock();
                sound.setMusicEnabled(next);
              }}
            >
              {"\u{1F3B5}"}
              <span className="icon-btn__text">{musicOn ? "Music" : "No music"}</span>
            </button>

            <input
              className="slider"
              type="range"
              min={0}
              max={100}
              value={Math.round(volume * 100)}
              aria-label="Volume"
              disabled={muted}
              onChange={(e) => {
                const next = Number(e.target.value) / 100;
                setVolume(next);
                sound.setVolume(next);
              }}
            />
          </div>
        </div>

        <div className="game-page__row game-page__row--actions">
          <Button
            variant="primary"
            className="btn--spin"
            disabled={busy || insufficient}
            onClick={() => void spin(false)}
            data-testid="spin-button"
          >
            {busy ? "Spinning" : "Spin"}
          </Button>

          {config.buy_bonus_enabled ? (
            <Button
              disabled={busy || insufficient || (balance ?? 0) < buyCost}
              onClick={() => void spin(true)}
              data-testid="buy-bonus-button"
            >
              Buy bonus
              <span className="btn__sub">{money(buyCost, config.currency)}</span>
            </Button>
          ) : null}

          {autoRunning ? (
            <Button variant="ghost" onClick={stopAuto} data-testid="stop-auto">
              Stop
              <span className="btn__sub">{autoSpin} left</span>
            </Button>
          ) : (
            <Button
              variant="ghost"
              disabled={busy || insufficient}
              onClick={() => {
                sound.unlock();
                sound.play("button");
                setAutoSpin(config.auto_play_max_spins);
                setAutoRunning(true);
              }}
              data-testid="auto-button"
            >
              Auto play
              <span className="btn__sub">{config.auto_play_max_spins} spins</span>
            </Button>
          )}
        </div>

        {insufficient ? (
          <p className="game-page__note">
            Not enough credits for this bet. Lower the stake or top up in your{" "}
            <Link to="/account/wallet">wallet</Link>.
          </p>
        ) : null}
      </Panel>

      <Panel title="About this game">
        <p className="muted">
          The outcome is decided on the server from a recorded random seed, then played back here.
          The client never chooses a result, and an awarded bonus plays every spin it was granted.
        </p>
        <dl className="paytable">
          {maths.symbols.map((s) => (
            <div className="paytable__row" key={s.key}>
              <dt>{s.label}</dt>
              <dd className="muted">{describeSymbol(s.key, maths.theme)}</dd>
            </div>
          ))}
        </dl>
        <p className="muted small">
          Return to player is set to {config.rtp_percent}% and can be changed from the admin area.
          Play money only — no real currency is involved.
        </p>
      </Panel>
    </div>
  );
}

function Readout({ label, value, testId }: { label: string; value: string; testId?: string }) {
  return (
    <div className="readout">
      <span className="readout__label">{label}</span>
      <strong className="readout__value" data-testid={testId}>
        {value}
      </strong>
    </div>
  );
}

function describeSymbol(key: string, theme: "dragon" | "buffalo"): string {
  if (key === "WILD") return "Substitutes for any symbol except Scatter.";
  if (key === "SCATTER") return "Three or more anywhere pays and awards free spins.";
  if (theme === "buffalo" && key === "BUFF") return "Three or more anywhere multiply the whole spin.";
  return "Pays on any payline from three of a kind.";
}