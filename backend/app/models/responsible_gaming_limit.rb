class ResponsibleGamingLimit < ApplicationRecord
  belongs_to :user
  belongs_to :set_by, class_name: "User", optional: true

  enum :kind, { deposit: 0, loss: 1, wager: 2, session_time: 3, session_count: 4 }
  enum :period, { daily: 0, weekly: 1, monthly: 2, session: 3, permanent: 4 }, default: :daily

  validates :effective_from, presence: true
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :current, -> { where(active: true).where("effective_from <= ?", Time.current)
                         .where("effective_until IS NULL OR effective_until > ?", Time.current) }

  # Responsible-gaming limits may only ever be tightened by a player; this is
  # enforced in the service layer (ResponsibleGaming::SetLimit).
  def amount
    return nil if amount_minor.nil?

    format("%.2f", amount_minor / 100.0)
  end
end
