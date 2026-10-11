class PlatformSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :category, presence: true

  scope :editable, -> { where(editable: true) }

  def self.value_for(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.value = value
    record.save!
    record
  end
end
