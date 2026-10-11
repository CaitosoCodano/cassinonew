module Api
  module V1
    module Admin
      # Catalogue administration: register titles and take them in or out of
      # service. Payout maths lives in GameConfigController; this controller
      # owns identity, status and bet limits.
      class GamesController < BaseController
        # GET /api/v1/admin/games
        def index
          scope = Game.order(:name)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(game_provider_id: params[:provider_id]) if params[:provider_id].present?
          scope = scope.where("slug LIKE :q OR name LIKE :q", q: "%#{params[:q]}%") if params[:q].present?

          render json: {
            data: scope.limit(200).map { |g| serialize(g) },
            meta: { count: scope.count }
          }
        end

        # POST /api/v1/admin/games
        def create
          game = Game.new(game_params)

          if game.save
            Audit::Record.call(
              actor: current_user,
              action: "admin.game_created",
              auditable: game,
              metadata: { slug: game.slug, status: game.status },
              request: request
            )
            render json: { data: serialize(game) }, status: :created
          else
            render json: {
              error: { code: "invalid_game", message: "The game could not be created.",
                       details: game.errors.to_hash }
            }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/admin/games/:id
        def update
          game = Game.find(params[:id])
          before = game.attributes.slice("slug", "name", "status", "min_bet_minor", "max_bet_minor")

          if game.update(game_params)
            Audit::Record.call(
              actor: current_user,
              action: "admin.game_updated",
              auditable: game,
              metadata: { before: before, after: game.attributes.slice(*before.keys) },
              request: request
            )
            render json: { data: serialize(game) }
          else
            render json: {
              error: { code: "invalid_game", message: "The game could not be updated.",
                       details: game.errors.to_hash }
            }, status: :unprocessable_entity
          end
        end

        private

        def game_params
          params.require(:game).permit(
            :game_provider_id, :slug, :name, :description, :category, :status,
            :thumbnail_url, :min_bet_minor, :max_bet_minor, :released_at,
            supported_currencies: []
          )
        end

        def serialize(game)
          {
            id: game.id,
            slug: game.slug,
            name: game.name,
            description: game.description,
            category: game.category,
            status: game.status,
            playable: game.playable?,
            # True only when the slug has maths registered in Games::Registry.
            registered: ::Games::Registry.registered?(game.slug),
            min_bet_minor: game.min_bet_minor,
            max_bet_minor: game.max_bet_minor,
            supported_currencies: game.supported_currencies,
            provider: { id: game.game_provider_id, name: game.game_provider.name },
            released_at: game.released_at&.iso8601
          }
        end
      end
    end
  end
end