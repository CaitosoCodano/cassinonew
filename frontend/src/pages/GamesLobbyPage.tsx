import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Alert, EmptyState, Eyebrow, Input, Panel, Spinner } from "../components/ui";
import { PageHeader } from "../components/ui";
import { api, apiErrorMessage } from "../lib/api";
import { money } from "../lib/format";
import type { Game } from "../lib/types";

// Visual identity per title. Kept here rather than in the API so the lobby can
// be restyled without a backend change.
const ART: Record<string, { mark: string; blurb: string; tags: string[] }> = {
  dragon_fortune: {
    mark: "\u{1F409}",
    blurb: "Eastern dragon reels with a scatter ladder that climbs a free-spin multiplier.",
    tags: ["20 paylines", "Free spins", "Buy bonus"],
  },
  buffalo_fortune: {
    mark: "\u{1F403}",
    blurb: "Stampede multipliers pay anywhere while the eagle and bison fill the low reels.",
    tags: ["20 paylines", "Stampede", "Buy bonus"],
  },
};

export default function GamesLobbyPage() {
  const [games, setGames] = useState<Game[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.games
      .list({ q: q || undefined })
      .then((res) => {
        if (cancelled) return;
        setGames(res.data);
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
  }, [q]);

  // Client-side grouping keeps the page useful without a category endpoint call.
  const { live, comingSoon } = useMemo(() => {
    return {
      live: games.filter((g) => g.playable),
      comingSoon: games.filter((g) => !g.playable),
    };
  }, [games]);

  return (
    <div>
      <PageHeader
        title="Games lobby"
        eyebrow="Luminara Originals"
        lead={
          <>
            Server-decided outcomes with a full bonus paid out in one round. Every title below is
            playable with play-money credits.
          </>
        }
      />

      {error ? (
        <Alert tone="error" className="mb-2">
          {error}
        </Alert>
      ) : null}

      <Panel className="mb-2">
        <div className="field">
          <label className="field-label" htmlFor="search">
            Search games
          </label>
          <Input
            id="search"
            placeholder="Search by title or slug"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
      </Panel>

      {loading ? (
        <div className="mt-3">
          <Spinner label="Loading games" />
        </div>
      ) : games.length === 0 ? (
        <EmptyState
          title="No games available"
          copy={
            <>
              This environment has no active titles. The platform shows a real empty state rather
              than inventing games, providers or balances.
            </>
          }
        />
      ) : (
        <>
          <section className="mb-3">
            <Eyebrow>{live.length} playable</Eyebrow>
            <div className="grid-3">
              {live.map((g) => (
                <GameCard key={g.id} game={g} />
              ))}
            </div>
          </section>

          {comingSoon.length > 0 ? (
            <section className="mb-3">
              <Eyebrow>{comingSoon.length} not yet playable</Eyebrow>
              <div className="grid-3">
                {comingSoon.map((g) => (
                  <GameCard key={g.id} game={g} />
                ))}
              </div>
            </section>
          ) : null}
        </>
      )}
    </div>
  );
}

function GameCard({ game }: { game: Game }) {
  const art = ART[game.slug];

  if (!game.playable) {
    return (
      <div className="game-card game-card--disabled" aria-disabled="true">
        <span className="game-card__mark" aria-hidden="true">
          {art?.mark ?? "\u{1F3B2}"}
        </span>
        <h3 className="game-card__name">{game.name}</h3>
        <p className="game-card__meta">{game.provider.name}</p>
        <p className="game-card__blurb">Not available in this environment.</p>
      </div>
    );
  }

  return (
    <Link className="game-card game-card--playable" to={`/games/${game.slug}`}>
      <span className="game-card__mark" aria-hidden="true">
        {art?.mark ?? "\u{1F3B2}"}
      </span>
      <h3 className="game-card__name">{game.name}</h3>
      <p className="game-card__meta">{game.provider.name}</p>
      {art?.blurb ? <p className="game-card__blurb">{art.blurb}</p> : null}
      <ul className="game-card__tags">
        {(art?.tags ?? []).map((t) => (
          <li key={t}>{t}</li>
        ))}
      </ul>
      <div className="game-card__foot">
        <span>
          {money(game.min_bet_minor ?? 0, "VCR")} – {money(game.max_bet_minor ?? 0, "VCR")}
        </span>
        <span className="game-card__cta">Play</span>
      </div>
    </Link>
  );
}