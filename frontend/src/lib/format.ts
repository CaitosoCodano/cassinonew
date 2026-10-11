// Formatting helpers for money (minor units), dates and identifiers.

/** Short alias used by the game surfaces. */
export function money(amountMinor: number, currency = "VCR"): string {
  return formatMinor(amountMinor, currency);
}

/** Format a number of minor units (100 = 1 unit) with the given currency code. */
export function formatMinor(amountMinor: number, currency: string): string {
  const sign = amountMinor < 0 ? "-" : "";
  const absolute = Math.abs(amountMinor);
  const isVirtual = import.meta.env.VITE_VIRTUAL_CURRENCY_MINOR_ZERO?.toString() === "true" || currency === "VCR";
  if (isVirtual) {
    const whole = Math.floor(absolute / 100);
    return `${sign}${whole.toLocaleString("en-GB")} ${currency}`;
  }
  const value = (absolute / 100).toFixed(2);
  return `${sign}${Number(value).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${currency}`;
}

/** Format an ISO 8601 timestamp as a local date + time string. */
export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("en-GB", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

/** Format an ISO 8601 date (yyyy-mm-dd) as a local date string. */
export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const [y, m, d] = iso.slice(0, 10).split("-").map(Number);
  if (!y || !m || !d) return iso;
  return new Intl.DateTimeFormat("en-GB", { year: "numeric", month: "short", day: "numeric" }).format(new Date(y, m - 1, d));
}

/** Humanize a snake_case identifier: kebab_case -> Kebab Case. */
export function humanize(value: string | null | undefined): string {
  if (!value) return "—";
  return value
    .replace(/[_-]+/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Relative time (e.g. "5m ago") for audit/activity lists. */
export function timeAgo(iso: string | null | undefined): string {
  if (!iso) return "—";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  const seconds = Math.round((date.getTime() - Date.now()) / 1000);
  const abs = Math.abs(seconds);
  if (abs < 60) return seconds < 0 ? "just now" : "now";
  if (abs < 3600) return `${Math.round(abs / 60)}m ago`;
  if (abs < 86400) return `${Math.round(abs / 3600)}h ago`;
  if (abs < 86400 * 30) return `${Math.round(abs / 86400)}d ago`;
  return formatDate(iso);
}

/** Client-generated idempotency key for wallet adjustments. */
export function idempotencyKey(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `k_${Date.now().toString(36)}_${Math.random().toString(36).slice(2)}`;
}
