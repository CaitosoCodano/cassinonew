class Wallet < ApplicationRecord
  belongs_to :user

  has_many :transactions, dependent: :restrict_with_error
  has_many :ledger_entries, dependent: :restrict_with_error
  has_many :game_sessions, dependent: :restrict_with_error

  # Virtual = play/promotional credits (no monetary value).
  # Real    = reserved for a future regulated real-money integration and is
  #           never enabled unless Platform.real_money_enabled? is true.
  enum :kind, { virtual: 0, real: 1 }, default: :virtual
  # prefixed to avoid `frozen?` (Object#frozen?) and `active` collisions
  enum :status, { active: 0, frozen: 1, closed: 2 }, prefix: :status, default: :active

  validates :currency, presence: true, format: { with: /\A[A-Z0-9]{3}\z/ }
  validates :balance_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind, uniqueness: { scope: %i[user_id currency] }

  # Human-readable balance derived from the integer minor units.
  def balance
    format("%.2f", balance_minor / 100.0)
  end

  def usable?
    status_active? && !status_closed?
  end
end
