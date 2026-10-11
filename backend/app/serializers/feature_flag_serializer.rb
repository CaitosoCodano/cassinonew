class FeatureFlagSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      key: record.key,
      enabled: record.enabled,
      description: record.description,
      rollout_percentage: record.rollout_percentage,
      updated_at: record.updated_at
    }
  end
end
