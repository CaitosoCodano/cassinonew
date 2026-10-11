// Shared API types. Field names mirror the backend serializers exactly.

export interface User {
  id: number;
  email: string;
  status: string;
  email_verified: boolean;
  role: string | null;
  last_sign_in_at: string | null;
  created_at: string;
}

export interface Profile {
  display_name: string | null;
  first_name: string | null;
  last_name: string | null;
  date_of_birth: string | null;
  country_code: string | null;
  phone: string | null;
  locale: string | null;
  marketing_opt_in: boolean | null;
  identity_verification_status: string | null;
  identity_reviewed_at: string | null;
}

export interface Wallet {
  id: number;
  kind: string;
  currency: string;
  balance_minor: number;
  balance: string;
  status: string;
  real_money: boolean;
  updated_at: string;
}

export interface Reconciliation {
  wallet_id: number;
  consistent: boolean;
  ledger_total_minor: number;
  wallet_balance_minor: number;
  discrepancy_minor: number;
}

export interface Transaction {
  id: number;
  kind: string;
  status: string;
  amount_minor: number;
  amount: string;
  currency: string;
  balance_before_minor: number | null;
  balance_after_minor: number | null;
  description: string | null;
  provider: string | null;
  external_reference: string | null;
  processed_at: string | null;
  created_at: string;
}

export interface LedgerEntry {
  id: number;
  sequence: number;
  entry_type: string;
  amount_minor: number;
  balance_after_minor: number;
  transaction_id: number;
  created_at: string;
}

export interface SessionInfo {
  id: number;
  device: string | null;
  ip_address: string | null;
  last_seen_at: string | null;
  expires_at: string | null;
  revoked: boolean;
  current: boolean;
  created_at: string;
}

export interface AccountRestriction {
  id: number;
  kind: string;
  status: string;
  reason: string | null;
  starts_at: string;
  ends_at: string | null;
  open_ended: boolean;
  lifted_at: string | null;
  created_at: string;
}

export interface ResponsibleGamingLimit {
  id: number;
  kind: string;
  period: string;
  amount_minor: number;
  amount: string;
  duration_seconds: number | null;
  active: boolean;
  effective_from: string;
  effective_until: string | null;
  set_by_player: boolean;
  created_at: string;
}

export interface AuditEvent {
  id: number;
  action: string;
  auditable_type: string | null;
  auditable_id: number | null;
  metadata: Record<string, unknown> | null;
  ip_address: string | null;
  created_at: string;
}

export interface SupportRequest {
  id: number;
  subject: string;
  message: string;
  category: string;
  status: string;
  priority: string;
  user_id: number | null;
  assigned_to_id: number | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface GameProviderRef {
  id: number;
  slug: string;
  name: string;
  status: string;
}

export interface Game {
  id: number;
  slug: string;
  name: string;
  description: string | null;
  category: string;
  status: string;
  thumbnail_url: string | null;
  min_bet_minor: number | null;
  max_bet_minor: number | null;
  supported_currencies: string[];
  provider: GameProviderRef;
  playable: boolean;
  released_at: string | null;
}

export interface GameProvider {
  id: number;
  slug: string;
  name: string;
  description: string | null;
  status: string;
  health_status: string;
  integration_version: string | null;
  capabilities: string[];
  available: boolean;
  adapter_configured: boolean;
  game_count: number;
}

export interface GameCategory {
  key: string;
  label: string;
  count: number;
}

export interface FeatureFlag {
  id: number;
  key: string;
  enabled: boolean;
  description: string | null;
  rollout_percentage: number | null;
  updated_at: string;
}

export interface PlatformSetting {
  id: number;
  key: string;
  value: string;
  category: string;
  description: string | null;
  editable: boolean;
  updated_at: string;
}

export interface SystemInfo {
  environment: string;
  database: { adapter: string; connected: boolean };
  cache_store: string;
  job_adapter: string;
  redis_configured: boolean;
  real_money_enabled: boolean;
  registered_adapters: string[];
  counts: {
    users: number;
    active_users: number;
    pending_users: number;
    game_providers: number;
    active_game_providers: number;
    games: number;
    active_games: number;
    open_support_requests: number;
    transactions: number;
    ledger_entries: number;
  };
  integration_status: Array<{
    slug: string;
    status: string;
    health_status: string;
    adapter_configured: boolean;
    integration_version: string | null;
    last_health_check_at: string | null;
  }>;
}

export interface CurrencyConfig {
  code: string;
  type: "virtual" | "real";
  label: string;
  enabled: boolean;
}

export interface PlatformConfig {
  brand: { name: string; descriptor: string; support_email: string };
  real_money_enabled: boolean;
  minimum_age: number;
  currencies: CurrencyConfig[];
  feature_flags: string[];
  self_exclusion: { cool_off_hours: number; self_exclusion_min_days: number };
  legal: { content_requires_review: boolean; note: string };
}

export interface WalletData {
  wallets: Wallet[];
  reconciliation: Reconciliation[];
  real_money_enabled: boolean;
}

export interface AccountData {
  user: User;
  profile: Profile | null;
  wallets: Wallet[];
  restrictions: AccountRestriction[];
  limits: ResponsibleGamingLimit[];
  verification: { email_verified: boolean; identity_status: string };
}

export interface AdminUserDetail {
  user: User;
  profile: Profile | null;
  wallets: Wallet[];
  restrictions: AccountRestriction[];
  active_sessions: number;
}

export interface GameSessionLaunch {
  game_session_id: number;
  launch_url: string;
}

export interface PageMeta {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export interface Paginated<T> {
  data: T[];
  meta: PageMeta;
}

/** Server error payload from { error: { code, message, details } }. */
export interface ApiErrorPayload {
  error: { code: string; message: string; details?: unknown };
}

export type AdminIntegrationStatus = SystemInfo["integration_status"][number];