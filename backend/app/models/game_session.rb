class GameSession < ApplicationRecord
  belongs_to :user
  belongs_to :game
  belongs_to :wallet

  enum :status,
       { pending: 0, active: 1, ended: 2, expired: 3, terminated: 4 },
       default: :pending

  scope :live, -> { where(status: %i[pending active]) }

  def end!(status: :ended)
    update!(status: status, ended_at: Time.current)
  end
end
