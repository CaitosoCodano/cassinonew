class ResponsibleGamingLimitSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      kind: record.kind,
      period: record.period,
      amount_minor: record.amount_minor,
      amount: record.amount,
      duration_seconds: record.duration_seconds,
      active: record.active,
      effective_from: record.effective_from,
      effective_until: record.effective_until,
      set_by_player: record.set_by_id == record.user_id,
      created_at: record.created_at
    }
  end
end
