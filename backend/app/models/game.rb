class Game < ApplicationRecord
  belongs_to :game_provider, inverse_of: :games

  has_many :game_sessions, dependent: :restrict_with_error

  enum :category,
       { slot: 0, table: 1, live: 2, instant: 3, crash: 4, other: 5 },
       prefix: :category,
       default: :other

  # coming_soon is the default: a registered game is not exposed to players
  # until an operator explicitly activates it.
  enum :status,
       { active: 0, inactive: 1, hidden: 2, coming_soon: 3 },
       default: :coming_soon

  validates :slug, presence: true, format: { with: /\A[a-z0-9][a-z0-9\-_]{0,79}\z/ }
  validates :name, presence: true
  validates :slug, uniqueness: { scope: :game_provider_id }

  scope :playable, -> { where(status: :active) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  def playable?
    active? && game_provider.available?
  end
end
