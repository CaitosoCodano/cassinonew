class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password

  belongs_to :role

  has_one :profile, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :wallets, dependent: :destroy
  has_many :email_verification_tokens, dependent: :destroy
  has_many :password_reset_tokens, dependent: :destroy
  has_many :transactions, through: :wallets
  has_many :ledger_entries, through: :wallets
  has_many :game_sessions, dependent: :destroy
  has_many :responsible_gaming_limits, dependent: :destroy
  has_many :account_restrictions, dependent: :destroy
  has_many :support_requests, dependent: :nullify
  has_many :audit_events, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor

  # pending = registered, email not yet verified
  # active  = fully usable
  # suspended = blocked by an operator / restriction
  # closed  = account deletion requested
  enum :status, { pending: 0, active: 1, suspended: 2, closed: 3 }, default: :pending

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email,
            presence: true,
            uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  validate :password_complexity, if: -> { password.present? }

  scope :recent, -> { order(created_at: :desc) }

  def self.find_by_email(email)
    find_by(email: email.to_s.strip.downcase)
  end

  def permission?(permission)
    role&.permission?(permission) || false
  end

  def admin?
    role&.admin? || false
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current) unless email_verified?
  end

  def locked?
    locked_at.present?
  end

  def virtual_wallet
    wallets.virtual.first
  end

  # Whether a currently-active restriction blocks gameplay / deposits.
  def restricted?(kind = nil)
    active = account_restrictions.active_now
    kind ? active.any? { |r| r.kind.to_s == kind.to_s } : active.exists?
  end

  private

  def password_complexity
    return if password.blank?

    errors.add(:password, "must include a letter") unless password.match?(/[A-Za-z]/)
    errors.add(:password, "must include a number") unless password.match?(/\d/)
  end
end
