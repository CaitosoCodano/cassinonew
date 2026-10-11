require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Only loads a smaller set of middleware suitable for API only apps.
    config.api_only = true

    # --- Session / cookie middleware -----------------------------------------
    # API mode strips cookie + session middleware. The web client is a
    # first-party SPA served from the same origin (or behind the Vite dev
    # proxy), so we re-enable an HttpOnly, SameSite session cookie and rely on
    # Rails' CSRF protection for state-changing requests. No bearer tokens are
    # persisted in localStorage / JS-accessible storage.
    config.session_store :cookie_store,
      key: "_luminara_session",
      same_site: :lax,
      httponly: true,
      secure: Rails.env.production?

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options

    # --- Application configuration -------------------------------------------
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Active Job uses the in-process async adapter in dev/test so the platform
    # boots with zero external services. Production is expected to configure a
    # durable adapter (see README -> Background jobs).
    config.active_job.queue_adapter = :async

    # Generators: we do not use view/helper/asset generators in this API app.
    config.generators do |g|
      g.system_tests = nil
      g.helper false
      g.assets false
    end
  end
end
