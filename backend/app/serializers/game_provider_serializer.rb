class GameProviderSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      slug: record.slug,
      name: record.name,
      description: record.description,
      status: record.status,
      health_status: record.health_status,
      integration_version: record.integration_version,
      capabilities: record.capabilities,
      available: record.available?,
      adapter_configured: record.adapter.present?,
      game_count: opts[:game_counts] ? opts[:game_counts].fetch(record.id, 0) : record.games.count
    }.compact
  end
end
