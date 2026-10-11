# Centralised platform configuration.
#
# The brand name and related identity values are placeholders that a deployment
# must override through environment variables. Nothing in the application
# hard-codes a real company's trademark.
module Platform
  BRAND_NAME = ENV.fetch("BRAND_NAME", "Luminara")
  BRAND_DESCRIPTOR = ENV.fetch("BRAND_DESCRIPTOR", "Premium Casino Platform")
  SUPPORT_EMAIL = ENV.fetch("SUPPORT_EMAIL", "support@example.invalid")

  # Root URL of the web client, used to build links in transactional email.
  # Falls back to RENDER_EXTERNAL_URL, which Render sets to the service's public
  # address, so a Render deployment works without anyone copying it by hand.
  WEB_CLIENT_URL = ENV["WEB_CLIENT_URL"].presence ||
                   ENV["RENDER_EXTERNAL_URL"].presence ||
                   "http://localhost:5173"

  # Modelling / regulatory posture. The platform ships as a VIRTUAL-CREDIT
  # sandbox only: no real-money functionality is enabled without the legal,
  # payment and licensing integrations described in the README.
  REAL_MONEY_ENABLED = ActiveModel::Type::Boolean.new.cast(ENV.fetch("REAL_MONEY_ENABLED", "false"))

  # Session lifetimes (server-enforced). Absolute is the hard maximum age of a
  # session; idle is the maximum inactivity before a session is revoked.
  SESSION_ABSOLUTE_TTL = ENV.fetch("SESSION_ABSOLUTE_TTL_HOURS", "12").to_i.hours
  SESSION_IDLE_TIMEOUT = ENV.fetch("SESSION_IDLE_TIMEOUT_MINUTES", "30").to_i.minutes

  def self.real_money_enabled?
    REAL_MONEY_ENABLED
  end
end
