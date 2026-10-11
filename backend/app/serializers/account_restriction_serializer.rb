class AccountRestrictionSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      kind: record.kind,
      status: record.status,
      reason: record.reason,
      starts_at: record.starts_at,
      ends_at: record.ends_at,
      open_ended: record.open_ended?,
      lifted_at: record.lifted_at,
      created_at: record.created_at
    }
  end
end
