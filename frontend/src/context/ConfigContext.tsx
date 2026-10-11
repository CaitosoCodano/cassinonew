import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api, ApiError } from "../lib/api";
import type { PlatformConfig } from "../lib/types";

// Local fallback used only while the server config is loading. The authoritative
// brand/descriptor always comes from GET /api/v1/config.
const FALLBACK: PlatformConfig = {
  brand: { name: "Luminara", descriptor: "Premium casino platform", support_email: "support@luminara.example" },
  real_money_enabled: false,
  minimum_age: 18,
  currencies: [
    { code: "VCR", type: "virtual", label: "Virtual credits", enabled: true },
    { code: "EUR", type: "real", label: "Euro", enabled: false },
  ],
  feature_flags: [],
  self_exclusion: { cool_off_hours: 24, self_exclusion_min_days: 1 },
  legal: { content_requires_review: true, note: "" },
};

interface ConfigContextValue {
  config: PlatformConfig;
  /** True once the server config has been fetched (successfully or not). */
  ready: boolean;
  /** Non-fatal load problem (app still runs with fallback config). */
  error: ApiError | null;
}

const ConfigContext = createContext<ConfigContextValue | null>(null);

export function ConfigProvider({ children }: { children: ReactNode }) {
  const [config, setConfig] = useState<PlatformConfig>(FALLBACK);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  useEffect(() => {
    let cancelled = false;
    api
      .config()
      .then((c) => {
        if (cancelled) return;
        setConfig(c);
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setError(e instanceof ApiError ? e : new ApiError(0, "config_failed", "Could not load platform configuration."));
      })
      .finally(() => {
        if (!cancelled) setReady(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return <ConfigContext.Provider value={{ config, ready, error }}>{children}</ConfigContext.Provider>;
}

export function useConfig(): ConfigContextValue {
  const ctx = useContext(ConfigContext);
  if (!ctx) throw new Error("useConfig must be used within <ConfigProvider>");
  return ctx;
}

export function useBrand() {
  const { config } = useConfig();
  return config.brand;
}