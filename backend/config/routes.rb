Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Public configuration (brand, currencies, feature flags, posture).
      get "config", to: "config#show"

      # --- Authentication ----------------------------------------------------
      namespace :auth do
        get    "csrf",          to: "csrf#show"
        get    "session",       to: "sessions#show"
        post   "register",      to: "registrations#create"
        post   "login",         to: "sessions#create"
        delete "logout",        to: "sessions#destroy"
        delete "logout_all",    to: "sessions#destroy_all"
        post   "password/forgot", to: "passwords#create"
        post   "password/reset",  to: "passwords#update"
        post   "email/verify",    to: "email_verifications#create"
        post   "email/resend",    to: "email_verifications#resend"
      end

      # --- Account -----------------------------------------------------------
      get   "account",          to: "account#show"
      patch "account/profile",  to: "account#update"
      patch "account/password", to: "account#update_password"

      namespace :account do
        resources :sessions, only: %i[index destroy]
        resources :activity, only: %i[index]
      end

      # --- Wallet ------------------------------------------------------------
      resource :wallet, only: [:show], controller: "wallet"
      get  "wallet/ledger", to: "wallet/ledger_entries#index"
      post "wallet/deposits",    to: "wallet/deposits#create"
      post "wallet/withdrawals", to: "wallet/withdrawals#create"
      namespace :wallet do
        resources :transactions, only: %i[index show]
      end

      # --- Game catalog ------------------------------------------------------
      resources :games, only: %i[index show] do
        resources :sessions, only: [:create], controller: "game_sessions"
        resources :rounds, only: [:create], controller: "games/rounds"
      end

      # Public maths + play configuration for a title (no auth required).
      get "games/:slug/maths", to: "games/maths#show", as: :game_maths

      resources :game_providers, only: [:index]
      get "game_categories", to: "game_categories#index"

      # --- Provider callbacks (unauthenticated, signature-verified) ----------
      post "provider_callbacks/:provider_slug", to: "provider_callbacks#create",
                                                as: :provider_callback

      # --- Responsible gaming ------------------------------------------------
      namespace :responsible_gaming do
        resources :limits, only: %i[index create]
        resources :restrictions, only: [:index]
        post "self_exclusion", to: "self_exclusions#create"
      end

      # --- Support -----------------------------------------------------------
      namespace :support do
        resources :requests, only: %i[index create]
      end

      # --- Administration (role-gated) --------------------------------------
      namespace :admin do
        get "system", to: "system#show"

        # Game maths + payout configuration (audited on every change).
        get  "game_config",      to: "game_config#show"
        patch "game_config",     to: "game_config#update"
        get  "game_config/rtp",  to: "game_config#rtp"

        resources :users, only: %i[index show update]
        resources :restrictions, only: %i[create update]
        resources :wallets, only: [] do
          post "adjustments", to: "wallet_adjustments#create"
        end
        resources :game_providers, only: %i[index create update]
        resources :games, only: %i[index create update]
        resources :feature_flags, only: %i[index create update]
        resources :platform_settings, only: %i[index update]
        resources :audit_events, only: [:index]
        resources :support_requests, only: %i[index update]
      end
    end
  end

  # In production the built SPA is served from public/. Any non-API path falls
  # through to index.html so client-side routing works.
  if Rails.env.production?
    root "static#index"
    get "*path", to: "static#index",
                 constraints: ->(request) { !request.path.start_with?("/api", "/up") },
                 format: false
  end
end
