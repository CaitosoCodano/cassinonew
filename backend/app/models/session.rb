class Session < ApplicationRecord
  belongs_to :user

  scope :active_now, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def active?
    revoked_at.nil? && expires_at.future?
  end

  def expired?
    expires_at.past?
  end

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  def touch_last_seen!
    # Avoid a write on every request: only update if stale by > 1 minute.
    return if last_seen_at.present? && last_seen_at > 1.minute.ago

    update_column(:last_seen_at, Time.current)
  end

  def device_label
    return "Unknown device" if user_agent.blank?

    ua = user_agent
    browser =
      if ua.include?("Edg/") then "Edge"
      elsif ua.include?("Chrome/") then "Chrome"
      elsif ua.include?("Firefox/") then "Firefox"
      elsif ua.include?("Safari/") then "Safari"
      else "Browser"
      end
    os =
      if ua.include?("Windows") then "Windows"
      elsif ua.include?("Mac OS") then "macOS"
      elsif ua.include?("Android") then "Android"
      elsif ua.include?("iPhone") || ua.include?("iPad") then "iOS"
      elsif ua.include?("Linux") then "Linux"
      else "Unknown OS"
      end
    "#{browser} on #{os}"
  end
end
