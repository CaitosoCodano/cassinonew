class GameRound < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :wallet

  enum :status, { pending: 0, in_progress: 1, completed: 2, cancelled: 3 }, prefix: false

  validates :bet_minor, numericality: { greater_than: 0 }, allow_nil: false
  validates :seed, presence: true
end
