import { useCallback, useEffect, useRef } from "react";
import type { GameGrid, LineWin } from "../lib/gameTypes";
import * as sound from "../lib/sound";

// ---------------------------------------------------------------------------
// The reel machine.
//
// How the motion works
// -------------------
// Each reel owns a strip of symbols long enough to cover the whole travel, and
// the *actual result is placed inside that strip* a fixed distance from the top.
// The reel then scrolls that strip upward and decelerates so it comes to rest
// with the result sitting exactly in the window.
//
// The important consequence: the symbols you eventually see are the same
// objects that were moving the whole time. There is no swap from "blur" to
// "result", so nothing pops into existence at the end of a spin.
//
// The animation runs on its own requestAnimationFrame clock and writes straight
// to the canvas. React state is never updated per frame -- routing the clock
// through state would re-render the page 60 times a second and the reels would
// visibly stutter.
// ---------------------------------------------------------------------------

// --- presentation ----------------------------------------------------------

interface Glyph {
  glyph: string;
  bg: string;
  fg: string;
  ring: string;
}

interface Theme {
  cellTop: string;
  cellBottom: string;
  cellEdge: string;
  frame: string;
  glyphs: Record<string, Glyph>;
  /** Symbols that scroll past while the reel travels. */
  scroll: string[];
}

const THEMES: Record<string, Theme> = {
  dragon: {
    cellTop: "#4a1226",
    cellBottom: "#24070f",
    cellEdge: "rgba(240, 196, 96, 0.30)",
    frame: "linear-gradient(180deg, #f7dc95 0%, #b8862f 52%, #f2c96b 100%)",
    glyphs: {
      "10": { glyph: "10", bg: "#1e40af", fg: "#eef4ff", ring: "#60a5fa" },
      J: { glyph: "J", bg: "#0f766e", fg: "#ecfdf5", ring: "#2dd4bf" },
      Q: { glyph: "Q", bg: "#7c2d12", fg: "#fff7ed", ring: "#fb923c" },
      K: { glyph: "K", bg: "#4c1d95", fg: "#f5f3ff", ring: "#a78bfa" },
      A: { glyph: "A", bg: "#9d174d", fg: "#fdf2f8", ring: "#f472b6" },
      DG: { glyph: "\u{1F409}", bg: "#065f46", fg: "#ecfdf5", ring: "#34d399" },
      DR: { glyph: "\u{1F525}", bg: "#9a3412", fg: "#fff7ed", ring: "#fbbf24" },
      WILD: { glyph: "W", bg: "#f7dc95", fg: "#40101f", ring: "#fff8e1" },
      SCATTER: { glyph: "S", bg: "#b91c1c", fg: "#fef2f2", ring: "#fca5a5" },
    },
    scroll: ["10", "J", "Q", "K", "A", "DG", "DR"],
  },
  buffalo: {
    cellTop: "#4d3119",
    cellBottom: "#20140a",
    cellEdge: "rgba(226, 178, 106, 0.28)",
    frame: "linear-gradient(180deg, #f2dcae 0%, #a97c2f 52%, #eacb8c 100%)",
    glyphs: {
      "10": { glyph: "10", bg: "#1e40af", fg: "#eef4ff", ring: "#60a5fa" },
      J: { glyph: "J", bg: "#0f766e", fg: "#ecfdf5", ring: "#2dd4bf" },
      Q: { glyph: "Q", bg: "#7c2d12", fg: "#fff7ed", ring: "#fb923c" },
      K: { glyph: "K", bg: "#4c1d95", fg: "#f5f3ff", ring: "#a78bfa" },
      A: { glyph: "A", bg: "#9d174d", fg: "#fdf2f8", ring: "#f472b6" },
      EAGLE: { glyph: "\u{1F985}", bg: "#1e3a8a", fg: "#eff6ff", ring: "#60a5fa" },
      BISON: { glyph: "\u{1F9AC}", bg: "#7c2d12", fg: "#fff7ed", ring: "#fb923c" },
      BUFF: { glyph: "\u{1F403}", bg: "#78350f", fg: "#fffbeb", ring: "#fbbf24" },
      WILD: { glyph: "W", bg: "#f2dcae", fg: "#3f2814", ring: "#fff8e1" },
      SCATTER: { glyph: "S", bg: "#b91c1c", fg: "#fef2f2", ring: "#fca5a5" },
    },
    scroll: ["10", "J", "Q", "K", "A", "EAGLE", "BISON", "BUFF"],
  },
};

const REELS = 5;
const ROWS = 3;
const GAP = 6;

/** Filler symbols above the result, i.e. how far the reel travels. */
const TRAVEL = 21;
/** Filler below the result, so the strip keeps scrolling past the window. */
const TAIL = 8;
const STRIP_LEN = TRAVEL + ROWS + TAIL;

/**
 * Reel deceleration.
 *
 * Fast off the mark, then a long tail into the stop. This is the curve that
 * makes a drum read as heavy: the symbol arrives rather than appearing.
 */
function spinEase(t: number): number {
  const clamped = t < 0 ? 0 : t > 1 ? 1 : t;
  return 1 - (1 - clamped) ** 3;
}

// --- props -----------------------------------------------------------------

export interface ReelTiming {
  delay: number;
  duration: number;
}

interface Props {
  theme: "dragon" | "buffalo";
  /** Final symbols for the spin on screen; null before the first spin. */
  grid: GameGrid | null;
  lineWins: LineWin[];
  timings: ReelTiming[];
  /** Increments once per spin; changing it restarts the reels. */
  spinToken: number;
  onReelStop: (reel: number) => void;
  onSpinComplete: () => void;
}

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  size: number;
  hue: number;
}

/** Mutable state the animation loop reads; never triggers a React render. */
interface LoopState {
  elapsed: number;
  lastReelStopped: number;
  strips: string[][];
  lastWinKey: string;
  celebrate: number;
  particles: Particle[];
  timings: ReelTiming[];
  grid: GameGrid | null;
  lineWins: LineWin[];
  theme: Theme;
}

export function SlotMachine({
  theme: themeName,
  grid,
  lineWins,
  timings,
  spinToken,
  onReelStop,
  onSpinComplete,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<HTMLDivElement>(null);

  const theme = THEMES[themeName] ?? THEMES.dragon;

  const stateRef = useRef<LoopState>({
    elapsed: -1,
    lastReelStopped: -1,
    strips: Array.from({ length: REELS }, () => buildStrip(null, theme, 0)),
    lastWinKey: "",
    celebrate: 0,
    particles: [],
    timings,
    grid,
    lineWins,
    theme,
  });

  // Hand the latest props to the loop before the next frame is painted.
  stateRef.current.timings = timings;
  stateRef.current.grid = grid;
  stateRef.current.lineWins = lineWins;
  stateRef.current.theme = theme;

  const callbacksRef = useRef({ onReelStop, onSpinComplete });
  callbacksRef.current = { onReelStop, onSpinComplete };

  // --- the render loop -----------------------------------------------------

  useEffect(() => {
    const canvas = canvasRef.current;
    const frame = frameRef.current;
    if (!canvas || !frame) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    let raf: number | null = null;

    const resize = () => {
      // Measure the frame, never the canvas. Sizing a canvas from its own box
      // feeds the ResizeObserver back into itself and the element grows.
      const rect = frame.getBoundingClientRect();
      const width = rect.width - 14;
      const height = rect.height - 14;
      if (width < 1 || height < 1) return;

      dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
    };

    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(frame);

    let last = performance.now();

    const tick = (now: number) => {
      // A backgrounded tab returns an enormous delta; clamping keeps the reels
      // moving smoothly instead of jumping to the end.
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      const state = stateRef.current;
      const W = canvas.width / dpr;
      const H = canvas.height / dpr;

      if (W >= 1 && H >= 1) {
        if (state.elapsed >= 0) {
          const lastTiming = state.timings[REELS - 1] ?? { delay: 0, duration: 0 };
          const total = lastTiming.delay + lastTiming.duration;
          state.elapsed = Math.min(total, state.elapsed + dt);

          for (let reel = 0; reel < REELS; reel += 1) {
            const timing = state.timings[reel];
            if (!timing) continue;
            if (state.elapsed >= timing.delay + timing.duration && state.lastReelStopped < reel) {
              state.lastReelStopped = reel;
              callbacksRef.current.onReelStop(reel);
            }
          }

          if (state.elapsed >= total && state.lastReelStopped >= REELS - 1) {
            state.elapsed = -1;
            callbacksRef.current.onSpinComplete();
          }
        }

        state.celebrate = Math.max(0, state.celebrate - dt * 0.45);
        draw(ctx, W, H, state, dt, now);
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);

    return () => {
      if (raf !== null) cancelAnimationFrame(raf);
      observer.disconnect();
    };
  }, []);

  // Start a new spin: rebuild the strips around the new result and rewind the
  // clock. The reels then travel and come to rest on those symbols.
  useEffect(() => {
    const state = stateRef.current;
    state.strips = Array.from({ length: REELS }, (_, reel) =>
      buildStrip(state.grid?.[reel] ?? null, state.theme, reel),
    );
    state.elapsed = 0;
    state.lastReelStopped = -1;
  }, [spinToken]);

  // A new winning set is a real state change, unlike the per-frame drawing, so
  // it belongs in an effect.
  const spawnCelebration = useCallback((intensity: number) => {
    const particles = stateRef.current.particles;
    const count = Math.round(intensity * 24);
    for (let i = 0; i < count; i += 1) {
      particles.push({
        x: 0.5 + (Math.random() - 0.5) * 0.85,
        y: 0.4 + (Math.random() - 0.5) * 0.25,
        vx: (Math.random() - 0.5) * 0.55,
        vy: -0.4 - Math.random() * 0.75,
        life: 1,
        maxLife: 1 + Math.random() * 1.1,
        size: 2 + Math.random() * 4,
        hue: 36 + Math.random() * 24,
      });
    }
    if (particles.length > 400) particles.splice(0, particles.length - 400);
  }, []);

  useEffect(() => {
    const key = lineWins.map((l) => `${l.index}:${l.count}:${l.symbol}`).join(",");
    if (key === stateRef.current.lastWinKey) return;
    stateRef.current.lastWinKey = key;
    if (lineWins.length === 0) return;

    stateRef.current.celebrate = 1;
    spawnCelebration(Math.min(4, lineWins.length));

    if (lineWins.length >= 3) sound.play("big-win");
    else if (lineWins.length === 2) sound.play("scatter");
    else sound.play("line-win");
  }, [lineWins, spawnCelebration]);

  return (
    <div className="reels" data-testid="slot-machine">
      <div className="reels__frame" ref={frameRef} style={{ background: theme.frame }}>
        <canvas ref={canvasRef} className="reels__canvas" role="img" aria-label="Slot reels" />
      </div>
      <p className="sr-only" role="status" aria-live="polite">
        {lineWins.length > 0
          ? `${lineWins.length} winning line${lineWins.length > 1 ? "s" : ""}`
          : "No winning line"}
      </p>
    </div>
  );
}

/**
 * Builds one reel's strip: filler, then the result, then more filler.
 *
 * The result sits at indices TRAVEL..TRAVEL+ROWS-1, so scrolling the strip up
 * by exactly TRAVEL cells lands it in the window.
 */
function buildStrip(result: string[] | null, theme: Theme, reel: number): string[] {
  const pool = theme.scroll;
  const strip: string[] = new Array(STRIP_LEN);

  // A per-real rotation keeps five reels from showing the same sequence.
  const shift = (reel * 3) % pool.length;

  for (let i = 0; i < STRIP_LEN; i += 1) {
    if (i >= TRAVEL && i < TRAVEL + ROWS && result) {
      strip[i] = result[i - TRAVEL] ?? pool[0];
    } else {
      strip[i] = pool[(i * 2 + shift) % pool.length];
    }
  }

  return strip;
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

function draw(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  state: LoopState,
  dt: number,
  now: number,
) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, W, H);

  const reelW = (W - GAP * (REELS + 1)) / REELS;
  const cellH = (H - GAP * (ROWS + 1)) / ROWS;
  const spinning = state.elapsed >= 0;

  for (let reel = 0; reel < REELS; reel += 1) {
    const timing = state.timings[reel] ?? { delay: 0, duration: 0 };
    const strip = state.strips[reel] ?? [];

    let offset = TRAVEL;
    let speed = 0;
    let sinceStop = -1;

    if (spinning) {
      const since = state.elapsed - timing.delay;
      if (since >= 0 && since < timing.duration) {
        const t = since / timing.duration;
        const prev = spinEase(Math.max(0, t - 0.016));
        offset = spinEase(t) * TRAVEL;
        // Cells per second, used to smear the symbols while they are moving.
        speed = Math.abs(offset - prev * TRAVEL) / 0.016;
      } else if (since >= 0) {
        offset = TRAVEL;
        sinceStop = since - timing.duration;
      }
    }

    const x = GAP + reel * (reelW + GAP);
    // A small press when the reel lands, so the result feels seated.
    const land = sinceStop >= 0 && sinceStop < 0.28 ? Math.sin((sinceStop / 0.28) * Math.PI) : 0;

    // Draw one row beyond each edge so the strip can scroll without a gap.
    for (let k = -1; k <= ROWS; k += 1) {
      const stripPos = offset + k;
      if (stripPos < 0 || stripPos >= STRIP_LEN) continue;

      const index = Math.floor(stripPos);
      const frac = stripPos - index;
      const y = GAP + (k + 1) * (cellH + GAP) - frac * cellH;
      if (y + cellH < 0 || y > H) continue;

      const symbol = strip[index] ?? "10";
      const glyph = state.theme.glyphs[symbol] ?? state.theme.glyphs["10"];

      // A cell holding a result symbol is a winning cell.
      const lit =
        !spinning && index >= TRAVEL && index < TRAVEL + ROWS && state.lineWins.length > 0
          ? state.lineWins.some((line) => line.cells.some(([c]) => c === reel))
          : false;

      drawCell(ctx, {
        x,
        y,
        w: reelW,
        h: cellH,
        theme: state.theme,
        glyph,
        lit,
        glow: state.celebrate,
        land,
        speed,
        cellH,
        now,
      });
    }
  }

  // Warm bloom around the frame while a win is being celebrated.
  if (state.lineWins.length > 0 && state.celebrate > 0) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.strokeStyle = `rgba(255, 231, 168, ${0.35 * state.celebrate})`;
    ctx.lineWidth = 3;
    ctx.strokeRect(1.5, 1.5, W - 3, H - 3);
    ctx.restore();
  }

  // Gold particles.
  const particles = state.particles;
  for (let i = particles.length - 1; i >= 0; i -= 1) {
    const p = particles[i];
    p.life -= dt / p.maxLife;
    if (p.life <= 0) {
      particles.splice(i, 1);
      continue;
    }
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += 2.4 * dt;

    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, p.life));
    ctx.fillStyle = `hsl(${p.hue}, 88%, ${56 + p.life * 20}%)`;
    ctx.beginPath();
    ctx.arc(p.x * W, p.y * H, p.size * p.life, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

interface CellArgs {
  x: number;
  y: number;
  w: number;
  h: number;
  theme: Theme;
  glyph: Glyph;
  lit: boolean;
  glow: number;
  land: number;
  speed: number;
  /** Cell height, so the motion smear can scale with the grid. */
  cellH: number;
  now: number;
}

function drawCell(ctx: CanvasRenderingContext2D, args: CellArgs) {
  const { x, y, w, h, theme, glyph, lit, glow, land, speed, cellH, now } = args;

  const grad = ctx.createLinearGradient(0, y, 0, y + h);
  grad.addColorStop(0, theme.cellTop);
  grad.addColorStop(1, theme.cellBottom);
  ctx.fillStyle = grad;
  roundRect(ctx, x, y, w, h, 10);
  ctx.fill();

  const pad = Math.min(w, h) * 0.15;
  const px = x + pad;
  const py = y + pad;
  const pw = w - pad * 2;
  const ph = h - pad * 2;

  // Vertical squash while landing, so the result is pressed into place.
  const squash = 1 + land * 0.05;
  ctx.save();
  ctx.translate(px + pw / 2, py + ph / 2);
  ctx.scale(1, squash);
  ctx.translate(-(px + pw / 2), -(py + ph / 2));

  const plate = ctx.createRadialGradient(
    px + pw * 0.35,
    py + ph * 0.25,
    ph * 0.08,
    px + pw / 2,
    py + ph / 2,
    ph * 0.95,
  );
  plate.addColorStop(0, glyph.bg);
  plate.addColorStop(1, shade(glyph.bg, -48));
  ctx.fillStyle = plate;
  roundRect(ctx, px, py, pw, ph, 12);
  ctx.fill();

  ctx.strokeStyle = withAlpha(glyph.ring, 0.35);
  ctx.lineWidth = 1.5;
  roundRect(ctx, px + 1, py + 1, pw - 2, ph - 2, 12);
  ctx.stroke();
  ctx.restore();

  // Motion smear: while the reel is moving quickly the glyph is drawn as a few
  // faint copies above and below, which reads as speed without a blur filter.
  const smear = Math.min(1, speed / 26);
  const size = Math.min(pw, ph) * 0.6;

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = `700 ${size}px "Segoe UI", system-ui, -apple-system, sans-serif`;
  ctx.shadowColor = "rgba(0,0,0,0.6)";
  ctx.shadowBlur = 4;
  ctx.shadowOffsetY = 1;
  ctx.fillStyle = glyph.fg;

  if (smear > 0.08) {
    ctx.save();
    ctx.globalAlpha = 0.3 * smear;
    const reach = cellH * 0.3 * smear;
    for (const dir of [-1, 1]) {
      for (let step = 1; step <= 2; step += 1) {
        ctx.fillText(glyph.glyph, px + pw / 2, py + ph / 2 + dir * reach * step);
      }
    }
    ctx.restore();
  }

  ctx.fillText(glyph.glyph, px + pw / 2, py + ph / 2);
  ctx.shadowBlur = 0;
  ctx.shadowOffsetY = 0;

  if (lit && glow > 0) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha = (0.28 + 0.32 * Math.abs(Math.sin(now / 220))) * glow;
    ctx.fillStyle = "#f7dc95";
    roundRect(ctx, x + 2, y + 2, w - 4, h - 4, 10);
    ctx.fill();
    ctx.restore();

    ctx.strokeStyle = "#fff8e1";
    ctx.lineWidth = 2;
    roundRect(ctx, x + 2, y + 2, w - 4, h - 4, 10);
    ctx.stroke();
  }

  ctx.strokeStyle = theme.cellEdge;
  ctx.lineWidth = 1;
  roundRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 10);
  ctx.stroke();
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

function shade(hex: string, amount: number): string {
  const n = parseInt(hex.replace("#", ""), 16);
  const clamp = (v: number) => Math.max(0, Math.min(255, v));
  return `rgb(${clamp(((n >> 16) & 0xff) + amount)}, ${clamp(((n >> 8) & 0xff) + amount)}, ${clamp((n & 0xff) + amount)})`;
}

function withAlpha(hex: string, alpha: number): string {
  const n = parseInt(hex.replace("#", ""), 16);
  return `rgba(${(n >> 16) & 0xff}, ${(n >> 8) & 0xff}, ${n & 0xff}, ${alpha})`;
}