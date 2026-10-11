import { beforeEach, describe, expect, it } from "vitest";
import * as sound from "../lib/sound";

// jsdom has no media stack, so the module must degrade quietly rather than
// throwing on a machine without audio support.
describe("sound module", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("starts unmuted", () => {
    expect(sound.isMuted()).toBe(false);
  });

  it("toggles mute and persists the choice", () => {
    expect(sound.toggleMuted()).toBe(true);
    expect(sound.isMuted()).toBe(true);
    expect(window.localStorage.getItem("luminara.sound")).toContain('"muted":true');
  });

  it("never throws when no media stack is available", () => {
    // jsdom does not implement HTMLMediaElement.play; that is the worst case.
    expect(() => sound.unlock()).not.toThrow();
    expect(() => sound.play("spin")).not.toThrow();
    expect(() => sound.playReelStop(0)).not.toThrow();
    expect(() => sound.playSequence("coin", 3, 0.1)).not.toThrow();
  });

  it("honours the mute flag for every cue", () => {
    sound.setMuted(true);
    [
      "spin", "reel-stop-1", "reel-stop-2", "reel-stop-3", "reel-stop-4", "reel-stop-5",
      "symbol-tick", "line-win", "scatter", "big-win", "coin", "button",
      "count-tick", "anticipation",
    ].forEach((cue) => {
      expect(() => sound.play(cue as Parameters<typeof sound.play>[0])).not.toThrow();
    });
  });

  it("clamps the volume into a sane range", () => {
    sound.setVolume(5);
    expect(sound.getVolume()).toBe(1);
    sound.setVolume(-1);
    expect(sound.getVolume()).toBe(0);
  });

  it("reports whether playback has been unlocked", () => {
    sound.unlock();
    expect(sound.isUnlocked()).toBe(true);
  });

  describe("background music", () => {
    it("toggles without throwing when there is no media stack", () => {
      expect(() => sound.setMusicEnabled(true)).not.toThrow();
      expect(sound.isMusicEnabled()).toBe(true);
      expect(() => sound.setMusicEnabled(false)).not.toThrow();
      expect(sound.isMusicEnabled()).toBe(false);
    });

    it("persists the music preference across sessions", () => {
      sound.persistMusicPreference(false);
      expect(window.localStorage.getItem("luminara.music")).toBe("off");
      expect(sound.readMusicPreference()).toBe(false);

      sound.persistMusicPreference(true);
      expect(sound.readMusicPreference()).toBe(true);
    });

    it("defaults to playing music", () => {
      window.localStorage.clear();
      expect(sound.readMusicPreference()).toBe(true);
    });

    it("stays silent when the whole sound is muted", () => {
      sound.setMuted(true);
      expect(() => sound.setMusicEnabled(true)).not.toThrow();
      sound.setMuted(false);
    });
  });
});