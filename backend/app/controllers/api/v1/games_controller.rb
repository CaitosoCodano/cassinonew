module Api
  module V1
    class GamesController < ApplicationController
      # GET /api/v1/games
      #
      # Public catalog. Only games that are active AND whose provider is
      # available are returned. With no integrations registered this is empty --
      # the lobby renders an honest empty state.
      def index
        scope = Game.where(status: :active)
                    .joins(:game_provider)
                    .where(game_providers: { status: [:active] })
                    .includes(:game_provider)
                    .order(:name)
        scope = scope.where(category: params[:category]) if params[:category].present?
        scope = scope.where(game_provider_id: params[:provider_id]) if params[:provider_id].present?

        if params[:q].present?
          like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
          scope = scope.where("games.name LIKE :q OR games.slug LIKE :q", q: like)
        end

        records, meta = paginate(scope)
        render_collection(
          records: records,
          serializer: GameSerializer,
          meta: meta.merge(
            available: any_game_available?,
            registered: Game.count,
            providers_available: GameProvider.active.count
          )
        )
      end

      # GET /api/v1/games/:id
      def show
        game = Game.where(status: :active)
                   .joins(:game_provider)
                   .where(game_providers: { status: [:active] })
                   .includes(:game_provider)
                   .find(params[:id])
        render_resource(game, serializer: GameSerializer)
      end

      private

      def any_game_available?
        Game.where(status: :active)
            .joins(:game_provider)
            .where(game_providers: { status: [:active] })
            .exists?
      end
    end
  end
end
