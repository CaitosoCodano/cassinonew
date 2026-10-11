class FeatureFlag < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :rollout_percentage, numericality: { only_integer: true, in: 0..100 }

  scope :on, -> { where(enabled: true) }

  # Reads a flag without raising when it has not been seeded.
  def self.enabled?(key)
    find_by(key: key)&.enabled? || false
  end
end
