module Api
  module V1
    class GameProvidersController < ApplicationController
      # GET /api/v1/game_providers
      # Public list of providers that are actually active. Never invents
      # providers -- with no registered integrations this is empty.
      def index
        providers = GameProvider.active.order(:name)
        counts = Game.playable.group(:game_provider_id).count

        render_collection(
          records: providers,
          serializer: GameProviderSerializer,
          meta: { total: providers.size },
          game_counts: counts,
          public_view: true
        )
      end
    end
  end
end
