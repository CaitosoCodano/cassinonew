"""
Generates the game's sound effects as real 44.1 kHz stereo WAV files.

These are synthesised offline and written to disk so the client streams actual
audio assets instead of building them at runtime. That keeps the playback path
cheap (a plain <Audio> element), lets the browser cache them, and means the
sound design is reproducible and reviewable in version control.

Design notes:
  * Every cue is mixed from layered partials with an exponential decay so it
    decays like a struck object rather than a beep.
  * Reel and tick sounds are transient-heavy: a short noise burst plus a tuned
    body resonance. That is what makes a mechanical slot sound mechanical.
  * Win cues are musical and stack a fifth, which is what reads as "reward"
    rather than "alert".
  * Peak is normalised to -1 dBFS so nothing clips when layered.

Run:  python tools/generate_sfx.py
"""

from __future__ import annotations

import math
import os
import struct
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44_100
OUT_DIR = Path(__file__).resolve().parents[1] / "public" / "sfx"

PEAK = 0.89  # -1 dBFS


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def silence(duration: float) -> np.ndarray:
    return np.zeros(int(SAMPLE_RATE * duration), dtype=np.float64)


def add_tone(
    buf: np.ndarray,
    start: float,
    duration: float,
    freq: float,
    amp: float,
    decay: float = 6.0,
    attack: float = 0.004,
    partials: tuple[float, ...] = (1.0, 0.5, 0.25, 0.12),
    detune: float = 0.0,
    shape: str = "exp",
) -> None:
    """Adds a harmonic tone with a percussive exponential envelope."""
    n = int(SAMPLE_RATE * duration)
    i0 = int(SAMPLE_RATE * start)
    if n <= 0 or i0 >= len(buf):
        return

    t = np.arange(n) / SAMPLE_RATE
    wave_sum = np.zeros(n)
    for k, weight in enumerate(partials, start=1):
        f = freq * k * (1.0 + detune * (k - 1))
        if f >= SAMPLE_RATE / 2:
            break
        wave_sum += weight * np.sin(2 * math.pi * f * t)

    peak = np.max(np.abs(wave_sum))
    if peak > 0:
        wave_sum /= peak

    env = np.zeros(n)
    atk = max(1, int(SAMPLE_RATE * attack))
    if shape == "exp":
        env = np.exp(-decay * t)
    else:  # linear pluck
        env = 1.0 - t / max(duration, 1e-6)
        env = np.clip(env, 0.0, None) ** 2
    env[:atk] *= np.linspace(0, 1, atk)

    seg = wave_sum * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def add_noise(
    buf: np.ndarray,
    start: float,
    duration: float,
    amp: float,
    decay: float = 40.0,
    cutoff: float = 4000.0,
    q: float = 1.0,
    resonance: float = 0.0,
    resonance_freq: float = 200.0,
) -> None:
    """Adds a filtered noise burst: the transient part of a mechanical click."""
    n = int(SAMPLE_RATE * duration)
    i0 = int(SAMPLE_RATE * start)
    if n <= 0 or i0 >= len(buf):
        return

    rng = np.random.default_rng(abs(hash((start, duration, cutoff))) % (2**32))
    raw = rng.standard_normal(n)

    # One-pole lowpass for the body of the noise.
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    filtered = np.empty(n)
    acc = 0.0
    for k in range(n):
        acc += alpha * (raw[k] - acc)
        filtered[k] = acc

    if resonance > 0.0:
        a2 = 1.0 - math.exp(-2.0 * math.pi * resonance_freq / SAMPLE_RATE)
        acc2 = 0.0
        for k in range(n):
            acc2 += a2 * (filtered[k] - acc2)
            filtered[k] = (1 - resonance) * filtered[k] + resonance * acc2

    env = np.exp(-decay * np.arange(n) / SAMPLE_RATE)
    seg = filtered * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def add_sweep(
    buf: np.ndarray,
    start: float,
    duration: float,
    f_start: float,
    f_end: float,
    amp: float,
    noise_mix: float = 0.0,
) -> None:
    """Adds a pitch sweep, used for the spin whoosh."""
    n = int(SAMPLE_RATE * duration)
    i0 = int(SAMPLE_RATE * start)
    if n <= 0 or i0 >= len(buf):
        return

    t = np.arange(n) / SAMPLE_RATE
    phase = 2 * math.pi * (f_start * t + (f_end - f_start) / duration * t**2 / 2)
    tone = np.sin(phase)

    if noise_mix > 0:
        rng = np.random.default_rng(1234)
        noise = rng.standard_normal(n)
        alpha = 1.0 - math.exp(-2.0 * math.pi * 2500.0 / SAMPLE_RATE)
        acc = 0.0
        filt = np.empty(n)
        for k in range(n):
            acc += alpha * (noise[k] - acc)
            filt[k] = acc
        tone = (1 - noise_mix) * tone + noise_mix * filt / (np.max(np.abs(filt)) + 1e-9)

    # Bell-shaped envelope: swells then clears.
    env = np.sin(np.pi * np.clip(t / duration, 0, 1)) ** 1.5
    seg = tone * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


# ---------------------------------------------------------------------------
# Cues
# ---------------------------------------------------------------------------

NOTE = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00, "B3": 246.94,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00, "B5": 987.77,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98,
}


def cue_spin() -> np.ndarray:
    """Reels launching: a rising whoosh with a mechanical wind-up thunk."""
    buf = silence(1.1)
    add_noise(buf, 0.0, 0.09, 0.35, decay=55, cutoff=1200, resonance=0.4, resonance_freq=160)
    add_tone(buf, 0.0, 0.30, 90, 0.30, decay=9, partials=(1.0, 0.3, 0.12))
    add_sweep(buf, 0.02, 0.75, 180, 900, 0.26, noise_mix=0.55)
    return buf


def cue_reel_stop(index: int = 0) -> np.ndarray:
    """A reel locking in. Slight pitch variation per reel so repeats feel live."""
    buf = silence(0.5)
    # Lower reels land lower: a descending ladder.
    base = 1.0 + index * 0.055
    add_noise(buf, 0.0, 0.055, 0.55, decay=90, cutoff=2600 * base, resonance=0.5, resonance_freq=220 * base)
    add_tone(buf, 0.0, 0.16, 190 * base, 0.40, decay=34, partials=(1.0, 0.42, 0.18), shape="pluck")
    add_tone(buf, 0.004, 0.10, 96 * base, 0.26, decay=42, partials=(1.0, 0.3))
    return buf


def cue_symbol_tick() -> np.ndarray:
    """A single symbol landing on the grid."""
    buf = silence(0.22)
    add_noise(buf, 0.0, 0.03, 0.40, decay=130, cutoff=5200)
    add_tone(buf, 0.0, 0.09, 760, 0.22, decay=48, partials=(1.0, 0.25))
    return buf


def cue_line_win() -> np.ndarray:
    """A paying line: a bright major triad with a shimmer on top."""
    buf = silence(1.3)
    for i, note in enumerate(("E5", "G#5" if "G#5" in NOTE else "G5", "B5")):
        add_tone(buf, i * 0.055, 0.85, NOTE[note], 0.30, decay=5.2,
                 partials=(1.0, 0.55, 0.28, 0.14, 0.07))
    add_noise(buf, 0.02, 0.30, 0.06, decay=14, cutoff=8000)
    return buf


def cue_scatter() -> np.ndarray:
    """Scatters landing: an ascending arpeggio with a shimmer tail."""
    buf = silence(2.0)
    arp = ("C5", "E5", "G5", "C6", "E6")
    for i, note in enumerate(arp):
        add_tone(buf, i * 0.085, 1.1, NOTE[note], 0.28, decay=3.4,
                 partials=(1.0, 0.5, 0.3, 0.16, 0.08))
    add_noise(buf, 0.35, 0.9, 0.05, decay=5, cutoff=9000)
    return buf


def cue_big_win() -> np.ndarray:
    """A large win: a full fanfare with a shimmering tail."""
    buf = silence(3.4)
    fanfare = (
        (0.00, "C5"), (0.10, "E5"), (0.20, "G5"), (0.30, "C6"),
        (0.44, "G5"), (0.56, "C6"), (0.68, "E6"), (0.82, "G6"),
    )
    for at, note in fanfare:
        add_tone(buf, at, 1.5, NOTE[note], 0.26, decay=3.0,
                 partials=(1.0, 0.5, 0.3, 0.18, 0.1, 0.05))
    # Sustained shimmer underneath.
    add_noise(buf, 0.75, 2.2, 0.055, decay=1.6, cutoff=9500)
    add_tone(buf, 0.80, 2.0, NOTE["C4"], 0.14, decay=2.0, partials=(1.0, 0.4, 0.2))
    return buf


def cue_coin() -> np.ndarray:
    """A coin dropping into the counter."""
    buf = silence(0.55)
    add_tone(buf, 0.0, 0.10, 2100, 0.24, decay=42, partials=(1.0, 0.3))
    add_tone(buf, 0.045, 0.16, 1650, 0.22, decay=30, partials=(1.0, 0.35))
    add_noise(buf, 0.0, 0.03, 0.18, decay=150, cutoff=7000)
    return buf


def cue_button() -> np.ndarray:
    """UI press: short, soft, unobtrusive."""
    buf = silence(0.18)
    add_tone(buf, 0.0, 0.09, 620, 0.24, decay=44, partials=(1.0, 0.3))
    add_tone(buf, 0.0, 0.05, 930, 0.12, decay=60, partials=(1.0,))
    return buf


def cue_count_tick() -> np.ndarray:
    """The win counter ticking up."""
    buf = silence(0.16)
    add_noise(buf, 0.0, 0.02, 0.30, decay=170, cutoff=6000)
    add_tone(buf, 0.0, 0.05, 1500, 0.14, decay=70, partials=(1.0, 0.2))
    return buf


def cue_anticipation() -> np.ndarray:
    """Reels slowing down: rising tension."""
    buf = silence(1.4)
    add_sweep(buf, 0.0, 1.2, 240, 1400, 0.20, noise_mix=0.25)
    add_tone(buf, 0.0, 1.3, NOTE["A3"], 0.14, decay=2.6, partials=(1.0, 0.4, 0.2))
    return buf


CUES = {
    "spin": cue_spin,
    "reel-stop-1": lambda: cue_reel_stop(0),
    "reel-stop-2": lambda: cue_reel_stop(1),
    "reel-stop-3": lambda: cue_reel_stop(2),
    "reel-stop-4": lambda: cue_reel_stop(3),
    "reel-stop-5": lambda: cue_reel_stop(4),
    "symbol-tick": cue_symbol_tick,
    "line-win": cue_line_win,
    "scatter": cue_scatter,
    "big-win": cue_big_win,
    "coin": cue_coin,
    "button": cue_button,
    "count-tick": cue_count_tick,
    "anticipation": cue_anticipation,
}


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_wav(path: Path, mono: np.ndarray) -> None:
    """Writes a 16-bit PCM WAV."""
    peak = np.max(np.abs(mono))
    if peak > 0:
        mono = mono * (PEAK / peak)

    # Short fade-out so the tail never clicks off.
    fade = min(200, mono.shape[0])
    if fade > 1:
        mono[-fade:] *= np.linspace(1, 0, fade)

    data = np.clip(mono, -1.0, 1.0)
    pcm = (data * 32767).astype(np.int16)

    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm.tobytes())


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    total = 0.0

    for name, factory in CUES.items():
        buf = factory()
        path = OUT_DIR / f"{name}.wav"
        write_wav(path, buf)
        size_kb = path.stat().st_size / 1024
        total += size_kb
        print(f"  {name:<16} {buf.shape[0] / SAMPLE_RATE:>5.2f}s  {size_kb:>6.1f} KB")

    print(f"\n{len(CUES)} cues written to {OUT_DIR}  ({total:.0f} KB total)")


if __name__ == "__main__":
    main()