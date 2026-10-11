# Rate limiting / throttling for authentication and sensitive endpoints.
# https://github.com/rack/rack-attack
#
# Storage: Redis in production (REDIS_URL), in-process memory store otherwise.
# Rack::Attack is disabled in the test suite by default (see Rack::Attack.enabled
# below) so shared request fixtures do not exhaust throttles; the dedicated
# throttling test re-enables it explicitly.

Rack::Attack.enabled = !Rails.env.test?

Rack::Attack.cache.store =
  if ENV["REDIS_URL"].present?
    require "redis"
    require "active_support/cache/redis_cache_store"
    ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
  else
    ActiveSupport::Cache::MemoryStore.new(size: 10.megabytes)
  end

# Never throttle the health check.
Rack::Attack.safelist("healthcheck") { |req| req.path == "/up" }

# --- Authentication throttles -------------------------------------------------
# Login / registration / password reset are the highest-value targets for
# credential stuffing and enumeration.

Rack::Attack.throttle("auth/ip", limit: 20, period: 60) do |req|
  req.ip if req.post? && req.path =~ %r{\A/api/v1/auth/(login|register|password)}
end

Rack::Attack.throttle("auth/email", limit: 10, period: 60) do |req|
  if req.post? && req.path =~ %r{\A/api/v1/auth/(login|password)}
    req.params["email"].to_s.downcase.presence
  end
end

# --- General API throttle -----------------------------------------------------
Rack::Attack.throttle("api/ip", limit: 300, period: 60) do |req|
  req.ip if req.path.start_with?("/api/v1")
end

# --- Provider callback throttle ----------------------------------------------
# Game providers sign their callbacks; this is a coarse safety net in addition
# to the HMAC verification performed by the integration layer.
Rack::Attack.throttle("provider_callbacks/ip", limit: 600, period: 60) do |req|
  req.ip if req.path.start_with?("/api/v1/provider_callbacks")
end

# Respond with a JSON 429 instead of the default plain-text body.
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"] || {}
  now = match_data[:epoch_time] || Time.now.to_i
  retry_after = match_data[:period] ? (match_data[:period] - (now % match_data[:period])) : 60

  [
    429,
    { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
    [{ error: { code: "rate_limited", message: "Too many requests. Please try again later." } }.to_json]
  ]
end
