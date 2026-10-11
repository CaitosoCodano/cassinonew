module Api
  module V1
    module Games
      # Plays a round. The outcome is computed entirely on the server; this
      # endpoint only accepts a stake and returns the resolved result.
      #
      # Note: domain services are referenced as `::Games` because a bare
      # `Games` resolves to this controller namespace from inside Api::V1.
      class RoundsController < ApplicationController
        before_action :authenticate_user!

        def create
          game = find_game!
          wallet = playable_wallet!

          result = ::Games::PlayService.new(
            game: game,
            user: current_user,
            wallet: wallet,
            bet_minor: params.require(:bet_minor),
            buy_bonus: buy_bonus_param,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          ).call

          Audit::Record.call(
            actor: current_user,
            action: "game.round_played",
            auditable: game,
            metadata: { round_id: result.round.id, bet_minor: result.bet_minor, win_minor: result.win_minor },
            request: request
          )

          render json: { data: serialize(result) }, status: :created
        rescue ::Games::Error => e
          render json: { error: { code: e.code.to_s, message: e.message } }, status: :unprocessable_entity
        rescue Ledger::InsufficientFunds
          render json: { error: { code: "insufficient_funds", message: "Not enough credits for this bet." } },
                 status: :unprocessable_entity
        rescue Ledger::Error => e
          render json: { error: { code: "wallet_error", message: e.message } }, status: :unprocessable_entity
        end

        private

        def find_game!
          slug = params[:game_slug].presence || Game.find_by(id: params[:game_id])&.slug
          raise ActiveRecord::RecordNotFound, "Game not found" if slug.blank?

          Game.find_by!(slug: slug)
        end

        def playable_wallet!
          current_user.wallets.find_by(kind: :virtual, currency: default_currency) ||
            current_user.wallets.where(currency: default_currency).first ||
            raise(ActiveRecord::RecordNotFound, "No wallet available for play money")
        end

        def default_currency
          ENV.fetch("PLAY_MONEY_CURRENCY", "VCR")
        end

        def buy_bonus_param
          ActiveModel::Type::Boolean.new.cast(params[:buy_bonus]).present?
        end

        def serialize(result)
          round = result.round
          outcome = result.outcome

          {
            id: round.id,
            game_slug: round.game.slug,
            bet_minor: result.bet_minor,
            win_minor: result.win_minor,
            balance_minor: result.balance_minor,
            status: round.status,
            seed: round.seed,
            events: outcome.events,
            grid: outcome.grid,
            line_wins: outcome.line_wins,
            scatter: outcome.scatter,
            base_units: outcome.base_units,
            buffalo_multiplier: outcome.buffalo_multiplier,
            free_spins: outcome.free_spins,
            total_units: outcome.total_units,
            started_at: round.started_at&.iso8601,
            ended_at: round.ended_at&.iso8601
          }
        end
      end
    end
  end
end