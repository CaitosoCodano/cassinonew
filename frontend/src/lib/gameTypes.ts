// Wire types for the game layer. These mirror the JSON produced by
// Games::RoundEngine exactly; if the backend shape changes, this file is the
// place that should fail to compile.

export type ReelSymbol = string;

/** grid[col][row] — five columns, three rows each. */
export type GameGrid = ReelSymbol[][];

export interface LineWin {
  index: number;
  /** [col, row] pairs that form the winning run. */
  cells: [number, number][];
  symbol: string;
  count: number;
  /** Win in line bets, before the operator RTP scale. */
  value: number;
}

export interface ScatterResult {
  count: number;
  positions: [number, number][];
}

export interface FreeSpinResult {
  index: number;
  grid: GameGrid;
  line_wins: LineWin[];
  scatter: ScatterResult;
  base_units: number;
  buffalo_multiplier: number;
  multiplier: number;
  win_units: number;
  total_after: number;
}

export type GameEvent = "scatter" | "buy_bonus" | "buffalo_stampede" | "free_spins";

export interface RoundResult {
  id: number;
  game_slug: string;
  bet_minor: number;
  win_minor: number;
  balance_minor: number;
  status: string;
  seed: string;
  events: GameEvent[];
  grid: GameGrid;
  line_wins: LineWin[];
  scatter: ScatterResult;
  base_units: number;
  buffalo_multiplier: number;
  free_spins: FreeSpinResult[];
  total_units: number;
  started_at: string;
  ended_at: string;
}

export interface GameSymbolInfo {
  key: string;
  label: string;
}

export interface GameMaths {
  theme: "dragon" | "buffalo";
  title: string;
  rows: number;
  reels: number;
  paylines: number;
  symbols: GameSymbolInfo[];
  features: string[];
  audio_theme: string;
}

export interface GamePlayConfig {
  min_bet_minor: number;
  max_bet_minor: number;
  default_bet_minor: number;
  buy_bonus_enabled: boolean;
  buy_bonus_cost_multiple: number;
  auto_play_max_spins: number;
  rtp_percent: number;
  currency: string;
}

export interface GameMathsResponse {
  game: {
    id: number;
    slug: string;
    name: string;
    description: string | null;
    status: string;
    min_bet_minor: number | null;
    max_bet_minor: number | null;
    playable: boolean;
  };
  maths: GameMaths;
  config: GamePlayConfig;
}

/** Playback speed presets offered in the HUD. */
export type SpinSpeed = "normal" | "fast" | "turbo";

export interface SpinSpeedProfile {
  id: SpinSpeed;
  label: string;
  /** Seconds each reel takes to travel. */
  reelDuration: number;
  /** Seconds between one reel stopping and the next. */
  reelStagger: number;
  /** Seconds the win presentation holds before control returns. */
  winHold: number;
}

// Timings were tuned by watching a full round: the reels need enough travel
// to read as spinning, and each reel must land clearly after the one before
// it. Normal is deliberately unhurried -- that is the reference experience
// Fast and Turbo are measured against.
export const SPIN_SPEEDS: Record<SpinSpeed, SpinSpeedProfile> = {
  normal: { id: "normal", label: "Normal", reelDuration: 2.6, reelStagger: 0.55, winHold: 2.6 },
  fast: { id: "fast", label: "Fast", reelDuration: 1.5, reelStagger: 0.3, winHold: 1.5 },
  turbo: { id: "turbo", label: "Turbo", reelDuration: 0.7, reelStagger: 0.12, winHold: 0.7 },
};

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

export interface GameAdminEntry {
  id: number;
  slug: string;
  name: string;
  status: string;
  playable: boolean;
  registered: boolean;
  paylines: number | null;
  theme: string | null;
  free_spin_awards: Record<string, number> | null;
  scatter_pays: Record<string, number> | null;
}

export interface GameAdminConfig {
  config: Record<string, number | boolean>;
  limits: Record<string, [number, number]>;
  defaults: Record<string, number | boolean>;
  registry: string[];
  games: GameAdminEntry[];
  overrides: {
    buy_bonus_disabled_by_env: boolean;
    free_spins_disabled_by_env: boolean;
  };
}

export interface RtpReportEntry {
  slug: string;
  spins: number;
  staked_minor: number;
  returned_minor: number;
  rtp_percent: number;
  scale: number;
  stdev_percent: number;
  margin_error_percent: number;
}

export interface RtpReport {
  spins: number;
  target_percent: number;
  games: RtpReportEntry[];
}