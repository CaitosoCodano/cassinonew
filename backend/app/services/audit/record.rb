module Audit
  # Writes an immutable audit event for administrative / financial actions.
  #
  #   Audit::Record.call(actor: current_user, action: "user.suspend",
  #                      auditable: target_user, metadata: { reason: "..." },
  #                      request: request)
  class Record
    def self.call(actor:, action:, auditable: nil, metadata: {}, request: nil, ip: nil, user_agent: nil)
      AuditEvent.create!(
        actor: actor,
        action: action,
        auditable_type: auditable&.class&.name,
        auditable_id: auditable&.id,
        metadata: metadata || {},
        ip_address: ip || request&.remote_ip,
        user_agent: user_agent || request&.user_agent,
        created_at: Time.current
      )
    end
  end
end
