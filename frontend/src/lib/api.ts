// Typed HTTP client for the Rails JSON API.
//
// Conventions:
//   - Session authentication is cookie-based. `credentials: "include"` is always
//     sent so the encrypted session cookie travels with every request.
//   - CSRF: state-changing requests carry the X-CSRF-Token header. The token is
//     issued by GET /auth/csrf and - because the session cookie rotates on
//     login/logout - must be re-fetched after any session-changing response.
//     Call `resetCsrf()` after login/logout/registration.
//   - Errors are normalized into ApiError (status, code, message, details).

import type {
  AccountData,
  AdminUserDetail,
  AuditEvent,
  FeatureFlag,
  Game,
  GameCategory,
  GameProvider,
  GameSessionLaunch,
  PageMeta,
  Paginated,
  PlatformConfig,
  PlatformSetting,
  Profile,
  ResponsibleGamingLimit,
  SessionInfo,
  SupportRequest,
  SystemInfo,
  Transaction,
  User,
  WalletData,
  AccountRestriction,
  LedgerEntry,
} from "./types";
import type { GameAdminConfig, GameMathsResponse, RoundResult, RtpReport } from "./gameTypes";

const BASE_URL: string = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "/api/v1";

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

/** Cached CSRF token bound to the current session cookie. */
let csrfToken: string | null = null;

/** Invalidate the cached CSRF token (required after login/logout/register). */
export function resetCsrf(): void {
  csrfToken = null;
}

export async function ensureCsrf(): Promise<string> {
  if (csrfToken) return csrfToken;
  const res = await fetch(`${BASE_URL}/auth/csrf`, {
    credentials: "include",
    headers: { Accept: "application/json" },
  });
  if (!res.ok) {
    throw new ApiError(res.status, "csrf_failed", "Could not obtain a session security token.");
  }
  const body = (await res.json()) as { data: { token: string } };
  csrfToken = body.data.token;
  return csrfToken;
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
  /** Attach a CSRF header (defaults to true for non-GET). */
  csrf?: boolean;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const method = options.method ?? "GET";
  const wantsCsrf = options.csrf ?? method !== "GET";

  const headers: Record<string, string> = { Accept: "application/json" };
  if (options.body !== undefined) headers["Content-Type"] = "application/json";
  if (wantsCsrf) headers["X-CSRF-Token"] = await ensureCsrf();

  // Retry once on 422 invalid_csrf_token: the session cookie may have rotated
  // (e.g. this request raced a login elsewhere); refetch and resend.
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers,
      credentials: "include",
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    });

    // The body is a one-shot stream: read it exactly once and keep the result.
    // Parsing it here for the CSRF check and again below meant every non-CSRF
    // 422 -- invalid bet, insufficient funds, buy bonus disabled -- died with
    // "body stream already read" instead of surfacing a usable message.
    const contentType = res.headers.get("content-type") ?? "";
    const hasJson = contentType.includes("application/json");
    const payload = res.status === 204 || !hasJson ? null : await res.json().catch(() => null);

    if (!res.ok && res.status === 422 && wantsCsrf && attempt === 0) {
      const code = (payload as { error?: { code?: string } } | null)?.error?.code;
      if (code === "invalid_csrf_token") {
        resetCsrf();
        headers["X-CSRF-Token"] = await ensureCsrf();
        continue;
      }
    }

    if (res.status === 204) return undefined as unknown as T;

    if (!res.ok) {
      const err = (payload as { error?: { code?: string; message?: string; details?: unknown } } | null)?.error;
      throw new ApiError(
        res.status,
        err?.code ?? "request_failed",
        err?.message ?? `Request failed (${res.status})`,
        err?.details,
      );
    }
    return payload as T;
  }

  throw new ApiError(500, "unknown", "Unexpected response.");
}

function paginationMeta(meta?: unknown): PageMeta | undefined {
  if (!meta || typeof meta !== "object") return undefined;
  return meta as PageMeta;
}

// ---------------------------------------------------------------------------
// Public configuration
// ---------------------------------------------------------------------------

export const api = {
  config: () => request<{ data: PlatformConfig }>("/config").then((r) => r.data),

  // --- Auth ---------------------------------------------------------------
  auth: {
    session: async (): Promise<User | null> => {
      const res = await fetch(`${BASE_URL}/auth/session`, { credentials: "include", headers: { Accept: "application/json" } });
      if (res.status === 204) return null;
      if (!res.ok) throw new ApiError(res.status, "session_failed", "Could not read your session.");
      const body = (await res.json()) as { data: User };
      return body.data;
    },
    login: async (email: string, password: string): Promise<User> => {
      resetCsrf();
      const body = await request<{ data: User }>("/auth/login", {
        method: "POST",
        body: { email, password },
      });
      resetCsrf();
      return body.data;
    },
    register: (payload: {
      email: string;
      password: string;
      password_confirmation: string;
      locale?: string;
      country_code?: string;
      marketing_opt_in?: boolean;
    }) => request<{ data: User }>("/auth/register", { method: "POST", body: payload }).then((r) => r.data),
    logout: async (): Promise<void> => {
      await request<void>("/auth/logout", { method: "DELETE" });
      resetCsrf();
    },
    logoutAll: async (): Promise<void> => {
      await request<void>("/auth/logout_all", { method: "DELETE" });
      resetCsrf();
    },
    forgotPassword: (email: string) =>
      request<{ data: { message: string } }>("/auth/password/forgot", { method: "POST", body: { email } }).then((r) => r.data),
    resetPassword: (payload: { token: string; password: string; password_confirmation: string }) =>
      request<void>("/auth/password/reset", { method: "POST", body: payload }),
    verifyEmail: (token: string) =>
      request<{ data: { email_verified: boolean } }>("/auth/email/verify", { method: "POST", body: { token } }).then((r) => r.data),
    resendVerification: () =>
      request<{ data: { email_verified: boolean; message: string } }>("/auth/email/resend", { method: "POST" }).then((r) => r.data),
  },

  // --- Account ------------------------------------------------------------
  account: {
    show: (): Promise<AccountData> => request<{ data: AccountData }>("/account").then((r) => r.data),
    updateProfile: (profile: Record<string, unknown>): Promise<Profile> =>
      request<{ data: Profile }>("/account/profile", { method: "PATCH", body: { profile } }).then((r) => r.data),
    changePassword: (payload: { current_password: string; password: string; password_confirmation: string }) =>
      request<{ data: { message: string } }>("/account/password", { method: "PATCH", body: payload }).then((r) => r.data),
    sessions: async (): Promise<Paginated<SessionInfo>> => {
      const body = await request<{ data: SessionInfo[]; meta?: unknown }>("/account/sessions");
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    revokeSession: (id: number) => request<void>(`/account/sessions/${id}`, { method: "DELETE" }),
    activity: async (page = 1): Promise<Paginated<AuditEvent>> => {
      const body = await request<{ data: AuditEvent[]; meta?: unknown }>(`/account/activity?page=${page}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
  },

  // --- Wallet -------------------------------------------------------------
  wallet: {
    show: (): Promise<WalletData> => request<{ data: WalletData }>("/wallet").then((r) => r.data),
    transactions: async (params: { wallet_id?: number; kind?: string; status?: string; page?: number } = {}): Promise<Paginated<Transaction>> => {
      const q = new URLSearchParams();
      if (params.wallet_id) q.set("wallet_id", String(params.wallet_id));
      if (params.kind) q.set("kind", params.kind);
      if (params.status) q.set("status", params.status);
      if (params.page) q.set("page", String(params.page));
      const body = await request<{ data: Transaction[]; meta?: unknown }>(`/wallet/transactions${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    ledger: async (params: { wallet_id?: number; page?: number } = {}): Promise<Paginated<LedgerEntry>> => {
      const q = new URLSearchParams();
      if (params.wallet_id) q.set("wallet_id", String(params.wallet_id));
      if (params.page) q.set("page", String(params.page));
      const body = await request<{ data: LedgerEntry[]; meta?: unknown }>(`/wallet/ledger${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
  },

  // --- Games --------------------------------------------------------------
  games: {
    list: async (params: { category?: string; q?: string; page?: number } = {}): Promise<Paginated<Game>> => {
      const q = new URLSearchParams();
      if (params.category) q.set("category", params.category);
      if (params.q) q.set("q", params.q);
      if (params.page) q.set("page", String(params.page));
      const body = await request<{ data: Game[]; meta?: unknown }>(`/games${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    show: (id: number): Promise<Game> => request<{ data: Game }>(`/games/${id}`).then((r) => r.data),

    /** Public maths + play configuration for a title. */
    maths: (slug: string): Promise<GameMathsResponse> =>
      request<{ data: GameMathsResponse }>(`/games/${slug}/maths`).then((r) => r.data),

    /**
     * Plays one round. The server resolves the entire round — paying spin,
     * every free spin, the running total — and returns it in one response, so
     * the client only ever animates an already-decided outcome.
     */
    spin: (gameId: number, payload: { bet_minor: number; buy_bonus?: boolean }): Promise<RoundResult> =>
      request<{ data: RoundResult }>(`/games/${gameId}/rounds`, {
        method: "POST",
        body: { bet_minor: payload.bet_minor, buy_bonus: Boolean(payload.buy_bonus) },
      }).then((r) => r.data),

    /** Replay a recorded round from its stored seed (used by support tooling). */
    round: (gameId: number, roundId: number): Promise<RoundResult> =>
      request<{ data: RoundResult }>(`/games/${gameId}/rounds/${roundId}`).then((r) => r.data),

    categories: (): Promise<GameCategory[]> => request<{ data: GameCategory[] }>("/game_categories").then((r) => r.data),
    providers: async (): Promise<{ data: GameProvider[]; meta?: unknown }> => request("/game_providers"),
    launch: (gameId: number): Promise<GameSessionLaunch> =>
      request<{ data: GameSessionLaunch }>(`/games/${gameId}/sessions`, { method: "POST" }).then((r) => r.data),
  },

  // --- Responsible gaming -------------------------------------------------
  rg: {
    limits: async (): Promise<ResponsibleGamingLimit[]> => request<{ data: ResponsibleGamingLimit[] }>("/responsible_gaming/limits").then((r) => r.data),
    setLimit: (payload: { kind: string; period?: string; amount_minor?: number; duration_seconds?: number }) =>
      request<{ data: ResponsibleGamingLimit }>("/responsible_gaming/limits", { method: "POST", body: payload }).then((r) => r.data),
    restrictions: async (): Promise<Paginated<AccountRestriction>> => {
      const body = await request<{ data: AccountRestriction[]; meta?: unknown }>("/responsible_gaming/restrictions");
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    selfExclude: (payload: { duration_days: number; reason?: string }) =>
      request<{ data: AccountRestriction }>("/responsible_gaming/self_exclusion", { method: "POST", body: payload }).then((r) => r.data),
  },

  // --- Support ------------------------------------------------------------
  support: {
    list: async (): Promise<Paginated<SupportRequest>> => {
      const body = await request<{ data: SupportRequest[]; meta?: unknown }>("/support/requests");
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    create: (payload: { subject: string; message: string; category?: string }) =>
      request<{ data: SupportRequest }>("/support/requests", { method: "POST", body: payload }).then((r) => r.data),
  },

  // --- Admin --------------------------------------------------------------
  admin: {
    system: (): Promise<SystemInfo> => request<{ data: SystemInfo }>("/admin/system").then((r) => r.data),
    users: async (params: { q?: string; status?: string; page?: number } = {}): Promise<Paginated<User>> => {
      const q = new URLSearchParams();
      if (params.q) q.set("q", params.q);
      if (params.status) q.set("status", params.status);
      if (params.page) q.set("page", String(params.page));
      const body = await request<{ data: User[]; meta?: unknown }>(`/admin/users${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    user: (id: number): Promise<AdminUserDetail> => request<{ data: AdminUserDetail }>(`/admin/users/${id}`).then((r) => r.data),
    updateUser: (id: number, payload: { role?: string; status?: string }) =>
      request<{ data: User }>(`/admin/users/${id}`, { method: "PATCH", body: payload }).then((r) => r.data),
    imposeRestriction: (payload: {
      user_id: number;
      kind: string;
      reason?: string;
      starts_at?: string;
      ends_at?: string | null;
    }): Promise<AccountRestriction> =>
      request<{ data: AccountRestriction }>("/admin/restrictions", { method: "POST", body: payload }).then((r) => r.data),
    liftRestriction: (id: number): Promise<AccountRestriction> =>
      request<{ data: AccountRestriction }>(`/admin/restrictions/${id}`, { method: "PATCH" }).then((r) => r.data),
    adjustWallet: (walletId: number, payload: { amount_minor: number; kind?: string; description?: string; idempotency_key?: string }) =>
      request<{ data: { wallet: WalletData["wallets"][number]; transaction: Transaction; replayed: boolean } }>(
        `/admin/wallets/${walletId}/adjustments`,
        { method: "POST", body: payload },
      ).then((r) => r.data),
    providers: async (): Promise<{ data: GameProvider[]; meta?: { registered_adapters: string[] } }> =>
      request("/admin/game_providers"),
    createProvider: (payload: Record<string, unknown>): Promise<GameProvider> =>
      request<{ data: GameProvider }>("/admin/game_providers", { method: "POST", body: { game_provider: payload } }).then((r) => r.data),
    updateProvider: (id: number, payload: Record<string, unknown>): Promise<GameProvider> =>
      request<{ data: GameProvider }>(`/admin/game_providers/${id}`, { method: "PATCH", body: { game_provider: payload } }).then((r) => r.data),
    games: async (): Promise<Paginated<Game>> => {
      const body = await request<{ data: Game[]; meta?: unknown }>("/admin/games");
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    createGame: (payload: Record<string, unknown>): Promise<Game> =>
      request<{ data: Game }>("/admin/games", { method: "POST", body: { game: payload } }).then((r) => r.data),
    updateGame: (id: number, payload: Record<string, unknown>): Promise<Game> =>
      request<{ data: Game }>(`/admin/games/${id}`, { method: "PATCH", body: { game: payload } }).then((r) => r.data),
    flags: (): Promise<FeatureFlag[]> => request<{ data: FeatureFlag[] }>("/admin/feature_flags").then((r) => r.data),
    createFlag: (payload: Record<string, unknown>): Promise<FeatureFlag> =>
      request<{ data: FeatureFlag }>("/admin/feature_flags", { method: "POST", body: { feature_flag: payload } }).then((r) => r.data),
    updateFlag: (id: number, payload: Record<string, unknown>): Promise<FeatureFlag> =>
      request<{ data: FeatureFlag }>(`/admin/feature_flags/${id}`, { method: "PATCH", body: { feature_flag: payload } }).then((r) => r.data),
    settings: async (): Promise<PlatformSetting[]> => request<{ data: PlatformSetting[] }>("/admin/platform_settings").then((r) => r.data),
    updateSetting: (id: number, payload: { value?: string; description?: string }): Promise<PlatformSetting> =>
      request<{ data: PlatformSetting }>(`/admin/platform_settings/${id}`, { method: "PATCH", body: { platform_setting: payload } }).then((r) => r.data),
    audit: async (params: { event_action?: string; actor_id?: number; auditable_type?: string; page?: number } = {}): Promise<Paginated<AuditEvent>> => {
      const q = new URLSearchParams();
      if (params.event_action) q.set("event_action", params.event_action);
      if (params.actor_id) q.set("actor_id", String(params.actor_id));
      if (params.auditable_type) q.set("auditable_type", params.auditable_type);
      if (params.page) q.set("page", String(params.page));
      const body = await request<{ data: AuditEvent[]; meta?: unknown }>(`/admin/audit_events${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    support: async (params: { status?: string; category?: string; priority?: string } = {}): Promise<Paginated<SupportRequest>> => {
      const q = new URLSearchParams();
      if (params.status) q.set("status", params.status);
      if (params.category) q.set("category", params.category);
      if (params.priority) q.set("priority", params.priority);
      const body = await request<{ data: SupportRequest[]; meta?: unknown }>(`/admin/support_requests${q.size ? `?${q}` : ""}`);
      return { data: body.data, meta: paginationMeta(body.meta) as PageMeta };
    },
    updateSupportRequest: (id: number, payload: { status?: string; priority?: string; assigned_to_id?: number }) =>
      request<{ data: SupportRequest }>(`/admin/support_requests/${id}`, { method: "PATCH", body: { support_request: payload } }).then((r) => r.data),
  },

  // --- Game maths ----------------------------------------------------------
  games_admin: {
    config: (): Promise<GameAdminConfig> => request<{ data: GameAdminConfig }>("/admin/game_config").then((r) => r.data),

    /** Persists maths settings. The server validates and audits every change. */
    updateConfig: (config: Record<string, unknown>): Promise<GameAdminConfig> =>
      request<{ data: GameAdminConfig }>("/admin/game_config", { method: "PATCH", body: { config } }).then((r) => r.data),

    /**
     * Measured return-to-player, from a Monte Carlo run on the server.
     * `spins` is capped server-side so the screen stays responsive.
     */
    rtp: (spins = 20_000): Promise<RtpReport> =>
      request<{ data: RtpReport }>(`/admin/game_config/rtp?spins=${spins}`).then((r) => r.data),
  },
};

export function apiErrorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}