class PasswordResetToken < ApplicationRecord
  belongs_to :user

  EXPIRY = 30.minutes

  scope :usable, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  # Issues a new token and returns the RAW token (only ever visible once, to be
  # emailed to the user). The digest is what is persisted.
  def self.issue!(user:, ip: nil)
    raw = SecureRandom.urlsafe_base64(32)
    user.password_reset_tokens.create!(
      token_digest: digest(raw),
      expires_at: EXPIRY.from_now,
      requested_ip: ip
    )
    raw
  end

  def self.find_usable_by_raw(raw_token)
    return nil if raw_token.blank?

    usable.find_by(token_digest: digest(raw_token))
  end

  def usable?
    used_at.nil? && expires_at.future?
  end

  def consume!
    update!(used_at: Time.current)
  end
end
