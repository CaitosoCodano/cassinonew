class GameProvider < ApplicationRecord
  has_many :games, dependent: :destroy
  # Nullify (rather than destroy) keeps the inbound-event audit trail intact.
  has_many :provider_events, dependent: :nullify
  has_many :game_sessions, through: :games

  enum :status, { active: 0, inactive: 1, maintenance: 2, error: 3 }, default: :inactive
  enum :health_status, { unknown: 0, healthy: 1, degraded: 2, down: 3 }, default: :unknown

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9\-_]{1,49}\z/ }
  validates :name, presence: true
  validate :adapter_is_registered, if: -> { adapter_class.present? }

  # Resolves the integration adapter for this provider. Never evaluates code;
  # the adapter must be explicitly registered in Games::ProviderRegistry.
  def adapter
    return nil if adapter_class.blank?

    Games::ProviderRegistry.resolve!(adapter_class)
  end

  def available?
    active? && (healthy? || unknown?)
  end

  private

  def adapter_is_registered
    Games::ProviderRegistry.resolve!(adapter_class)
  rescue Games::ProviderRegistry::UnknownAdapterError => e
    errors.add(:adapter_class, e.message)
  end
end
