class ProviderEvent < ApplicationRecord
  belongs_to :game_provider, optional: true
  belongs_to :game_session, optional: true

  enum :processing_status,
       { received: 0, processed: 1, rejected: 2, duplicate: 3 },
       default: :received

  validates :event_type, presence: true
  validates :external_id, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
end
