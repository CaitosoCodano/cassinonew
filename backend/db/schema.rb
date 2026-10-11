# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_10_231920) do
  create_table "account_restrictions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "imposed_by_id"
    t.integer "lifted_by_id"
    t.integer "kind", null: false
    t.integer "status", default: 0, null: false
    t.text "reason"
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.datetime "lifted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["imposed_by_id"], name: "index_account_restrictions_on_imposed_by_id"
    t.index ["kind"], name: "index_account_restrictions_on_kind"
    t.index ["lifted_by_id"], name: "index_account_restrictions_on_lifted_by_id"
    t.index ["user_id", "status"], name: "index_account_restrictions_on_user_id_and_status"
    t.index ["user_id"], name: "index_account_restrictions_on_user_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.integer "actor_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.json "metadata", default: {}, null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
  end

  create_table "email_verification_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_email_verification_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_email_verification_tokens_on_user_id"
  end

  create_table "feature_flags", force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", default: false, null: false
    t.string "description"
    t.integer "rollout_percentage", default: 100, null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_flags_on_key", unique: true
  end

  create_table "game_providers", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "status", default: 1, null: false
    t.string "adapter_class"
    t.string "integration_version"
    t.json "capabilities", default: {}, null: false
    t.json "config", default: {}, null: false
    t.integer "health_status", default: 0, null: false
    t.datetime "last_health_check_at"
    t.text "last_health_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_game_providers_on_slug", unique: true
    t.index ["status"], name: "index_game_providers_on_status"
  end

  create_table "game_rounds", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "user_id", null: false
    t.integer "wallet_id", null: false
    t.integer "bet_minor"
    t.integer "total_win_minor"
    t.integer "status"
    t.string "seed"
    t.json "state"
    t.json "result"
    t.json "metadata"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_game_rounds_on_game_id"
    t.index ["user_id"], name: "index_game_rounds_on_user_id"
    t.index ["wallet_id"], name: "index_game_rounds_on_wallet_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "game_id", null: false
    t.integer "wallet_id", null: false
    t.integer "status", default: 0, null: false
    t.string "provider_session_reference"
    t.string "token_digest"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "expires_at"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_game_sessions_on_game_id"
    t.index ["provider_session_reference"], name: "index_game_sessions_on_provider_session_reference"
    t.index ["status"], name: "index_game_sessions_on_status"
    t.index ["user_id", "status"], name: "index_game_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_game_sessions_on_user_id"
    t.index ["wallet_id"], name: "index_game_sessions_on_wallet_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "game_provider_id", null: false
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "category", default: 5, null: false
    t.integer "status", default: 3, null: false
    t.string "thumbnail_url"
    t.bigint "min_bet_minor"
    t.bigint "max_bet_minor"
    t.json "supported_currencies", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_games_on_category"
    t.index ["game_provider_id", "slug"], name: "index_games_on_game_provider_id_and_slug", unique: true
    t.index ["game_provider_id"], name: "index_games_on_game_provider_id"
    t.index ["status"], name: "index_games_on_status"
  end

  create_table "idempotency_records", force: :cascade do |t|
    t.string "scope", null: false
    t.string "key", null: false
    t.string "request_fingerprint"
    t.integer "status", default: 0, null: false
    t.integer "response_status"
    t.json "response_body", default: {}, null: false
    t.datetime "locked_at"
    t.datetime "completed_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_idempotency_records_on_expires_at"
    t.index ["scope", "key"], name: "index_idempotency_records_on_scope_and_key", unique: true
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "wallet_id", null: false
    t.integer "transaction_id", null: false
    t.bigint "sequence", null: false
    t.bigint "amount_minor", null: false
    t.bigint "balance_after_minor", null: false
    t.string "entry_type", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["transaction_id"], name: "index_ledger_entries_on_transaction_id"
    t.index ["wallet_id", "created_at"], name: "index_ledger_entries_on_wallet_id_and_created_at"
    t.index ["wallet_id", "sequence"], name: "index_ledger_entries_on_wallet_id_and_sequence", unique: true
    t.index ["wallet_id"], name: "index_ledger_entries_on_wallet_id"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.string "requested_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_password_reset_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "platform_settings", force: :cascade do |t|
    t.string "key", null: false
    t.json "value", default: {}, null: false
    t.string "category", default: "general", null: false
    t.string "description"
    t.boolean "editable", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_platform_settings_on_category"
    t.index ["key"], name: "index_platform_settings_on_key", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "display_name"
    t.string "first_name"
    t.string "last_name"
    t.date "date_of_birth"
    t.string "country_code", limit: 2
    t.string "phone"
    t.string "locale", default: "en", null: false
    t.integer "identity_verification_status", default: 0, null: false
    t.datetime "identity_reviewed_at"
    t.boolean "marketing_opt_in", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "provider_events", force: :cascade do |t|
    t.integer "game_provider_id"
    t.integer "game_session_id"
    t.string "event_type", null: false
    t.string "external_id", null: false
    t.json "payload", default: {}, null: false
    t.boolean "signature_valid", default: false, null: false
    t.integer "processing_status", default: 0, null: false
    t.text "error_message"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_provider_events_on_external_id", unique: true
    t.index ["game_provider_id"], name: "index_provider_events_on_game_provider_id"
    t.index ["game_session_id"], name: "index_provider_events_on_game_session_id"
    t.index ["processing_status"], name: "index_provider_events_on_processing_status"
  end

  create_table "responsible_gaming_limits", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "set_by_id"
    t.integer "kind", null: false
    t.integer "period", default: 0, null: false
    t.bigint "amount_minor"
    t.bigint "duration_seconds"
    t.boolean "active", default: true, null: false
    t.datetime "effective_from", null: false
    t.datetime "effective_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["set_by_id"], name: "index_responsible_gaming_limits_on_set_by_id"
    t.index ["user_id", "kind", "period"], name: "idx_rg_limits_active_unique", unique: true, where: "active = 1"
    t.index ["user_id"], name: "index_responsible_gaming_limits_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.json "permissions", default: [], null: false
    t.boolean "system", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_seen_at"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "support_requests", force: :cascade do |t|
    t.integer "user_id"
    t.integer "assigned_to_id"
    t.string "subject", null: false
    t.text "message", null: false
    t.integer "category", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 1, null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_support_requests_on_assigned_to_id"
    t.index ["category"], name: "index_support_requests_on_category"
    t.index ["status"], name: "index_support_requests_on_status"
    t.index ["user_id"], name: "index_support_requests_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "wallet_id", null: false
    t.integer "kind", null: false
    t.integer "status", default: 0, null: false
    t.bigint "amount_minor", null: false
    t.string "currency", limit: 3, null: false
    t.bigint "balance_before_minor", null: false
    t.bigint "balance_after_minor", null: false
    t.string "idempotency_key"
    t.string "provider"
    t.string "external_reference"
    t.string "description"
    t.json "metadata", default: {}, null: false
    t.integer "initiated_by_id"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_transactions_on_idempotency_key", unique: true, where: "idempotency_key IS NOT NULL"
    t.index ["initiated_by_id"], name: "index_transactions_on_initiated_by_id"
    t.index ["kind"], name: "index_transactions_on_kind"
    t.index ["wallet_id", "created_at"], name: "index_transactions_on_wallet_id_and_created_at"
    t.index ["wallet_id", "status"], name: "index_transactions_on_wallet_id_and_status"
    t.index ["wallet_id"], name: "index_transactions_on_wallet_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "email_verified_at"
    t.datetime "last_sign_in_at"
    t.integer "failed_sign_in_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["status"], name: "index_users_on_status"
  end

  create_table "wallets", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "kind", default: 0, null: false
    t.string "currency", limit: 3, default: "VCR", null: false
    t.bigint "balance_minor", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_wallets_on_kind"
    t.index ["user_id", "kind", "currency"], name: "index_wallets_on_user_id_and_kind_and_currency", unique: true
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "account_restrictions", "users"
  add_foreign_key "account_restrictions", "users", column: "imposed_by_id"
  add_foreign_key "account_restrictions", "users", column: "lifted_by_id"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "email_verification_tokens", "users"
  add_foreign_key "game_rounds", "games"
  add_foreign_key "game_rounds", "users"
  add_foreign_key "game_rounds", "wallets"
  add_foreign_key "game_sessions", "games"
  add_foreign_key "game_sessions", "users"
  add_foreign_key "game_sessions", "wallets"
  add_foreign_key "games", "game_providers"
  add_foreign_key "ledger_entries", "transactions"
  add_foreign_key "ledger_entries", "wallets"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "profiles", "users"
  add_foreign_key "provider_events", "game_providers"
  add_foreign_key "provider_events", "game_sessions"
  add_foreign_key "responsible_gaming_limits", "users"
  add_foreign_key "responsible_gaming_limits", "users", column: "set_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "support_requests", "users"
  add_foreign_key "support_requests", "users", column: "assigned_to_id"
  add_foreign_key "transactions", "users", column: "initiated_by_id"
  add_foreign_key "transactions", "wallets"
  add_foreign_key "users", "roles"
  add_foreign_key "wallets", "users"
end
