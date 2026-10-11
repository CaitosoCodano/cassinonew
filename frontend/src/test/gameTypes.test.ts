import { describe, expect, it } from "vitest";
import { SPIN_SPEEDS } from "../lib/gameTypes";

// The reel machine is driven entirely off these numbers, so a regression here
// is a regression in how the game feels.
describe("spin speed profiles", () => {
  it("offers exactly the three documented speeds", () => {
    expect(Object.keys(SPIN_SPEEDS).sort()).toEqual(["fast", "normal", "turbo"]);
  });

  it("orders the speeds from slowest to fastest", () => {
    const { normal, fast, turbo } = SPIN_SPEEDS;
    expect(turbo.reelDuration).toBeLessThan(fast.reelDuration);
    expect(fast.reelDuration).toBeLessThan(normal.reelDuration);
  });

  it("staggers reels less at higher speeds so the cascade stays readable", () => {
    expect(SPIN_SPEEDS.turbo.reelStagger).toBeLessThan(SPIN_SPEEDS.normal.reelStagger);
  });

  it("keeps a positive hold so a result is always visible before control returns", () => {
    Object.values(SPIN_SPEEDS).forEach((profile) => {
      expect(profile.winHold).toBeGreaterThan(0);
    });
  });

  it("keeps the fastest total round under three seconds", () => {
    const { turbo } = SPIN_SPEEDS;
    // Four reels of stagger after the first, plus the hold.
    const total = turbo.reelDuration + 4 * turbo.reelStagger + turbo.winHold;
    expect(total).toBeLessThan(3);
  });

  it("gives the normal mode enough travel to read as a spin, not a cut", () => {
    // Five reels staggered, plus the result hold before control returns.
    const { normal } = SPIN_SPEEDS;
    const total = normal.reelDuration + 4 * normal.reelStagger + normal.winHold;
    expect(total).toBeGreaterThan(4);
  });

  it("keeps each reel visibly longer than the stagger between reels", () => {
    // Otherwise the reels land together and the cascade is lost.
    Object.values(SPIN_SPEEDS).forEach((profile) => {
      expect(profile.reelDuration).toBeGreaterThan(profile.reelStagger * 3);
    });
  });
});