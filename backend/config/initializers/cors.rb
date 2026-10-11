# Cross-Origin Resource Sharing.
#
# The recommended local setup proxies /api from the Vite dev server to Rails,
# making requests same-origin and CORS unnecessary. This configuration exists
# for deployments where the SPA is hosted on a separate origin.
#
# Set CORS_ORIGINS to a comma-separated list of allowed origins. Credentials
# (session cookies) require explicit origins -- wildcards are intentionally not
# supported here.
allowed_origins = ENV.fetch("CORS_ORIGINS", "http://localhost:5173")
                     .split(",")
                     .map(&:strip)
                     .reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)
    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             expose: %w[X-Request-Id X-RateLimit-Limit X-RateLimit-Remaining]
  end
end
