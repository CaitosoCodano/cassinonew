class Profile < ApplicationRecord
  belongs_to :user

  enum :identity_verification_status,
       { not_started: 0, pending: 1, verified: 2, rejected: 3 },
       default: :not_started

  validates :country_code, format: { with: /\A[A-Za-z]{2}\z/ }, allow_blank: true
  validates :locale, inclusion: { in: %w[en pt es] }
  validates :date_of_birth,
            allow_nil: true,
            comparison: {
              less_than: -> { 18.years.ago.to_date },
              message: "must indicate the account holder is at least 18 years old"
            }

  def full_name
    [first_name, last_name].compact_blank.join(" ").presence
  end

  def display_name
    self[:display_name].presence || full_name || "Player"
  end
end
