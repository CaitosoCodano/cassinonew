class GameSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      slug: record.slug,
      name: record.name,
      description: record.description,
      category: record.category,
      status: record.status,
      thumbnail_url: record.thumbnail_url,
      min_bet_minor: record.min_bet_minor,
      max_bet_minor: record.max_bet_minor,
      supported_currencies: record.supported_currencies,
      provider: {
        id: record.game_provider_id,
        slug: record.game_provider.slug,
        name: record.game_provider.name,
        status: record.game_provider.status
      },
      playable: record.playable?,
      released_at: record.released_at
    }
  end
end
