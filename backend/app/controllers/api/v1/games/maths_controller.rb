module Api
  module V1
    module Games
      # Public game maths: how a title looks and plays before any bet is made.
      class MathsController < ApplicationController
        def show
          slug = params[:slug]
          # `::Games` is required throughout: inside Api::V1 a bare `Games`
          # resolves to this controller namespace, not the domain services.
          return render_error("not_found", "Unknown game.", :not_found) unless ::Games::Registry.registered?(slug)

          game = Game.find_by(slug: slug)
          return render_error("not_found", "Unknown game.", :not_found) unless game

          math = ::Games::Registry.math_for(slug)
          render json: {
            data: {
              game: GameSerializer.new(game).as_json,
              maths: math.metadata,
              config: public_config
            }
          }
        rescue StandardError => e
          render_error("maths_unavailable", e.message, :internal_server_error)
        end

        private

        # Only the knobs a player needs in order to pick a bet. Nothing here is
        # secret: the RTP target is disclosed on purpose.
        def public_config
          config = ::Games::Config.all
          {
            min_bet_minor: config["min_bet_minor"],
            max_bet_minor: config["max_bet_minor"],
            default_bet_minor: config["default_bet_minor"],
            buy_bonus_enabled: config["buy_bonus_enabled"],
            buy_bonus_cost_multiple: config["buy_bonus_cost_multiple"],
            auto_play_max_spins: config["auto_play_max_spins"],
            rtp_percent: config["user_rtp_percent"],
            currency: "VCR"
          }
        end

        def render_error(code, message, status)
          render json: { error: { code: code, message: message } }, status: status
        end
      end
    end
  end
end