class PlatformSettingSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      key: record.key,
      value: record.value,
      category: record.category,
      description: record.description,
      editable: record.editable,
      updated_at: record.updated_at
    }
  end
end
