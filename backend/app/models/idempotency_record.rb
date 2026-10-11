class IdempotencyRecord < ApplicationRecord
  enum :status, { in_progress: 0, completed: 1, failed: 2 }, default: :in_progress

  validates :scope, :key, presence: true
  validates :key, uniqueness: { scope: :scope }

  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at < ?", Time.current) }

  # Runs the block at most once per (scope, key).
  #
  #   IdempotencyRecord.once(scope: "provider_callback", key: external_id) { ... }
  #
  # Returns the recorded response on replay. Concurrency is protected by the
  # unique index: a racing insert raises RecordNotUnique and is treated as a
  # replay.
  def self.once(scope:, key:, fingerprint: nil, expires_in: 24.hours)
    existing = find_by(scope: scope, key: key)
    return existing.response_body if existing&.completed?

    record = begin
      create!(scope: scope, key: key, request_fingerprint: fingerprint,
              locked_at: Time.current, expires_at: expires_in.from_now)
    rescue ActiveRecord::RecordNotUnique
      return find_by(scope: scope, key: key)&.response_body
    end

    result = yield
    record.update!(status: :completed, completed_at: Time.current,
                   response_status: 200, response_body: result.is_a?(Hash) ? result : { result: result })
    result
  rescue StandardError => e
    record&.update!(status: :failed, response_status: 500, response_body: { error: e.class.name })
    raise
  end
end
