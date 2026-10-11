import { formatMinor, formatDateTime, humanize } from "../lib/format";

describe("formatting helpers", () => {
  it("formats minor units", () => {
    expect(formatMinor(100, "EUR")).toContain("EUR");
    expect(formatMinor(-50, "VCR")).toMatch(/-\d+\sVCR/);
  });

  it("formats dates safely", () => {
    expect(formatDateTime(null)).toBe("—");
    expect(formatDateTime("2026-10-10T12:00:00Z")).toBeTruthy();
  });

  it("humanizes snake case", () => {
    expect(humanize("deposit_limit")).toBe("Deposit Limit");
    expect(humanize("self_exclusion")).toBe("Self Exclusion");
  });
});