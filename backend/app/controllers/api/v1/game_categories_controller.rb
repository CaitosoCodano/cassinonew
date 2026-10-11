module Api
  module V1
    class GameCategoriesController < ApplicationController
      # GET /api/v1/game_categories
      def index
        counts = Game.playable.group(:category).count

        render json: {
          data: Game.categories.keys.map do |category|
            { key: category, label: category.titleize, count: counts[category].to_i }
          end
        }
      end
    end
  end
end
