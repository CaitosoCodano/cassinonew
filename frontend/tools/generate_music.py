"""
Generates the game's looping background music as a real WAV file.

Design goals
------------
* Seamless. Every voice is placed on a tempo grid and its envelope decays to
  silence before the loop point, so the last bar leads back into the first
  without a click or a change of key.
* Attractive without being punishing. A warm lounge pulse in a minor key:
  sustained pad, walking bass, a light arpeggio and restrained percussion.
  Nothing is shrill or busy enough to fight the reel-stop cues.
* Low dynamic range. The mix is normalised and then compressed by limiting the
  peak, because the music sits under the sound effects and must not mask them.

Run:  python tools/generate_music.py
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44_100
DURATION = 30.0
BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = int(round(DURATION / BAR))
OUT_DIR = Path(__file__).resolve().parents[1] / "public" / "sfx"

# A minor-key loop that resolves back to the root.
# Each entry is (root, third, fifth, seventh) in semitones from A2.
PROGRESSION = [
    (0, 3, 7, 10),   # Am7
    (0, 3, 7, 10),   # Am7
    (5, 8, 12, 15),  # Dm7
    (5, 8, 12, 15),  # Dm7
    (3, 7, 10, 14),  # Cmaj7
    (3, 7, 10, 14),  # Cmaj7
    (0, 4, 7, 11),   # A7sus-ish
    (0, 4, 7, 10),   # A7
]

ROOT_HZ = 110.0  # A2


def note(semitones: int, octave: int = 1) -> float:
    """Frequency for a semitone offset from the root at a given octave."""
    return ROOT_HZ * (2 ** ((semitones + 12 * octave) / 12.0))


def add_voice(
    buf: np.ndarray,
    start: float,
    duration: float,
    freq: float,
    amp: float,
    *,
    detune: float = 0.0,
    harmonics: tuple[float, ...] = (1.0, 0.5, 0.25),
    attack: float = 0.05,
    release: float = 0.6,
) -> None:
    """
    Adds one sustained voice with a soft attack and an exponential tail.

    The release finishes inside `duration` on purpose: nothing is allowed to
    ring past the loop point, or the seam would be audible.
    """
    n = int(SAMPLE_RATE * duration)
    i0 = int(SAMPLE_RATE * start)
    if n <= 2 or i0 >= len(buf):
        return

    t = np.arange(n) / SAMPLE_RATE
    tone = np.zeros(n)
    for k, weight in enumerate(harmonics, start=1):
        f = freq * k * (1.0 + detune * (k - 1))
        if f >= SAMPLE_RATE / 2:
            break
        tone += weight * np.sin(2 * math.pi * f * t)

    peak = np.max(np.abs(tone))
    if peak > 0:
        tone /= peak

    # Attack / sustain / release envelope.
    atk = max(1, int(SAMPLE_RATE * attack))
    rel = min(n - 1, int(SAMPLE_RATE * release))
    env = np.ones(n)
    env[:atk] = np.linspace(0, 1, atk)
    if rel > 0:
        tail = np.linspace(1, 0, rel) ** 1.6
        env[-rel:] = tail

    seg = tone * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def add_pluck(
    buf: np.ndarray,
    start: float,
    freq: float,
    amp: float,
    decay: float = 3.5,
) -> None:
    """A short bell-like note for the arpeggio."""
    n = int(SAMPLE_RATE * 0.6)
    i0 = int(SAMPLE_RATE * start)
    if n <= 2 or i0 >= len(buf):
        return

    t = np.arange(n) / SAMPLE_RATE
    tone = (
        np.sin(2 * math.pi * freq * t)
        + 0.45 * np.sin(2 * math.pi * freq * 2 * t)
        + 0.22 * np.sin(2 * math.pi * freq * 3 * t)
    )
    env = np.exp(-decay * t)
    env[: int(SAMPLE_RATE * 0.004)] *= np.linspace(0, 1, int(SAMPLE_RATE * 0.004))

    seg = tone * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def add_kick(buf: np.ndarray, start: float, amp: float) -> None:
    """A soft kick: a pitch drop with a short body."""
    n = int(SAMPLE_RATE * 0.28)
    i0 = int(SAMPLE_RATE * start)
    if n <= 2 or i0 >= len(buf):
        return

    t = np.arange(n) / SAMPLE_RATE
    freq = 95.0 * np.exp(-14.0 * t) + 42.0
    phase = 2 * math.pi * np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-11.0 * t)
    seg = np.sin(phase) * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def add_hat(buf: np.ndarray, start: float, amp: float, decay: float = 55.0) -> None:
    """A short noise tick, high-passed by differencing."""
    n = int(SAMPLE_RATE * 0.09)
    i0 = int(SAMPLE_RATE * start)
    if n <= 2 or i0 >= len(buf):
        return

    rng = np.random.default_rng(int(start * 1000) + 7)
    noise = rng.standard_normal(n)
    hp = np.diff(noise, prepend=0.0)
    env = np.exp(-decay * np.arange(n) / SAMPLE_RATE)
    seg = hp * env * amp
    end = min(i0 + n, len(buf))
    buf[i0:end] += seg[: end - i0]


def build_loop() -> np.ndarray:
    total = int(SAMPLE_RATE * DURATION)
    buf = np.zeros(total + SAMPLE_RATE)  # headroom for tails

    for bar_index in range(BARS):
        bar_start = bar_index * BAR
        chord = PROGRESSION[bar_index % len(PROGRESSION)]
        root, third, fifth, seventh = chord

        # --- pad: three detuned voices per chord tone, long and soft
        for interval in (root, third, fifth, seventh):
            for voice, detune in enumerate((-0.004, 0.0, 0.004)):
                add_voice(
                    buf,
                    bar_start,
                    BAR * 0.98,
                    note(interval, 1),
                    amp=0.055 if interval in (root, fifth) else 0.04,
                    detune=detune,
                    harmonics=(1.0, 0.42, 0.2, 0.08),
                    attack=0.28,
                    release=1.1,
                )

        # --- bass: root on beat one, fifth on beat three
        add_voice(
            buf, bar_start, BEAT * 1.6, note(root, 0),
            amp=0.16, harmonics=(1.0, 0.3, 0.1), attack=0.02, release=0.5,
        )
        add_voice(
            buf, bar_start + BEAT * 2, BEAT * 1.6, note(fifth, 0),
            amp=0.13, harmonics=(1.0, 0.3, 0.1), attack=0.02, release=0.5,
        )

        # --- arpeggio: eighth notes walking up and back down the chord
        arp = [root, third, fifth, seventh, fifth, third]
        for step in range(6):
            at = bar_start + step * (BEAT / 2)
            add_pluck(buf, at, note(arp[step], 2), amp=0.075, decay=4.2)

        # --- percussion: kick on 1 and 3, hat on the offbeats
        add_kick(buf, bar_start, 0.20)
        add_kick(buf, bar_start + BEAT * 2, 0.16)
        for step in range(4):
            at = bar_start + step * BEAT + BEAT / 2
            add_hat(buf, at, 0.05 if step % 2 == 0 else 0.035)

    buf = buf[:total]

    # A short fade at both ends removes the seam without an audible dip: the
    # loop point is silent for only ~15 ms.
    fade = int(SAMPLE_RATE * 0.015)
    buf[:fade] *= np.linspace(0, 1, fade)
    buf[-fade:] *= np.linspace(1, 0, fade)

    return buf


def normalise(buf: np.ndarray, peak: float = 0.55) -> np.ndarray:
    """Peak-normalises, then soft-limits anything above the target."""
    m = np.max(np.abs(buf))
    if m > 0:
        buf = buf * (peak / m)
    return np.tanh(buf * 1.15) / np.tanh(1.15)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    loop = build_loop()
    loop = normalise(loop)

    path = OUT_DIR / "music-loop.wav"
    fade = int(SAMPLE_RATE * 0.015)
    loop[:fade] *= np.linspace(0, 1, fade)
    loop[-fade:] *= np.linspace(1, 0, fade)

    pcm = (np.clip(loop, -1.0, 1.0) * 32767).astype(np.int16)

    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm.tobytes())

    size = path.stat().st_size / 1024
    print(f"music-loop.wav  {DURATION:.0f}s  {BPM:.0f} BPM  {size:.0f} KB  -> {path}")


if __name__ == "__main__":
    main()