module Api
  module V1
    module Admin
      class GameProvidersController < BaseController
        # GET /api/v1/admin/game_providers
        def index
          providers = GameProvider.order(:name)
          render_collection(
            records: providers,
            serializer: GameProviderSerializer,
            meta: { registered_adapters: Games::ProviderRegistry.registered.keys.sort },
            game_counts: Game.group(:game_provider_id).count
          )
        end

        # POST /api/v1/admin/game_providers
        def create
          provider = GameProvider.new(provider_params)
          provider.save!
          Audit::Record.call(actor: current_user, action: "admin.provider_created",
                             auditable: provider, metadata: { slug: provider.slug }, request: request)
          render_resource(provider, serializer: GameProviderSerializer, status: :created)
        end

        # PATCH /api/v1/admin/game_providers/:id
        def update
          provider = GameProvider.find(params[:id])
          provider.update!(provider_params)
          Audit::Record.call(actor: current_user, action: "admin.provider_updated",
                             auditable: provider, metadata: provider_params.to_h, request: request)
          render_resource(provider, serializer: GameProviderSerializer)
        end

        private

        def provider_params
          params.require(:game_provider).permit(
            :slug, :name, :description, :status, :adapter_class, :integration_version,
            capabilities: {}, config: {}
          )
        end
      end
    end
  end
end
