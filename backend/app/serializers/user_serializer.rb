class UserSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      email: record.email,
      status: record.status,
      email_verified: record.email_verified?,
      role: record.role&.name,
      last_sign_in_at: record.last_sign_in_at,
      created_at: record.created_at
    }
  end
end
