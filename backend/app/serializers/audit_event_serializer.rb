class AuditEventSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      action: record.action,
      auditable_type: record.auditable_type,
      auditable_id: record.auditable_id,
      metadata: record.metadata,
      ip_address: record.ip_address,
      created_at: record.created_at
    }
  end
end
