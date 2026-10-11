class SupportRequestSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      subject: record.subject,
      message: record.message,
      category: record.category,
      status: record.status,
      priority: record.priority,
      user_id: record.user_id,
      assigned_to_id: record.assigned_to_id,
      resolved_at: record.resolved_at,
      created_at: record.created_at,
      updated_at: record.updated_at
    }
  end
end
