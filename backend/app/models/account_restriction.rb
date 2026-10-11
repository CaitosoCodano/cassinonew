class AccountRestriction < ApplicationRecord
  belongs_to :user
  belongs_to :imposed_by, class_name: "User", optional: true
  belongs_to :lifted_by, class_name: "User", optional: true

  enum :kind,
       { self_exclusion: 0, cool_off: 1, suspension: 2, ban: 3,
         deposit_block: 4, wager_block: 5 }
  enum :status, { active: 0, expired: 1, lifted: 2 }, default: :active

  validates :starts_at, presence: true

  scope :active_now, lambda {
    where(status: :active)
      .where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at > ?", Time.current)
  }

  def open_ended?
    ends_at.nil?
  end

  def lift!(by:)
    update!(status: :lifted, lifted_at: Time.current, lifted_by: by)
  end
end
