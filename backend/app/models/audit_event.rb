class AuditEvent < ApplicationRecord
  # Append-only audit trail for administrative and financial actions.
  belongs_to :actor, class_name: "User", optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def readonly?
    persisted?
  end
end
