class SessionSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      device: record.device_label,
      ip_address: record.ip_address,
      last_seen_at: record.last_seen_at,
      expires_at: record.expires_at,
      revoked: record.revoked_at.present?,
      current: record.id == opts[:current_session_id],
      created_at: record.created_at
    }
  end
end
