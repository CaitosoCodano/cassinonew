module Api
  module V1
    class GameSessionsController < ApplicationController
      before_action :authenticate_active_user!

      # POST /api/v1/games/:game_id/sessions
      def create
        game = Game.find(params[:game_id])

        # `::Games` is required: inside Api::V1 the bare constant would resolve to
        # the Api::V1::Games controller namespace.
        result = ::Games::SessionLauncher.call(
          user: current_user,
          game: game,
          ip: request.remote_ip,
          user_agent: request.user_agent,
          locale: current_user.profile&.locale || "en"
        )

        if result.success?
          render json: {
            data: {
              game_session_id: result.game_session.id,
              launch_url: result.launch_url
            }
          }, status: :created
        else
          render_error(code: result.error.to_s, message: launch_message(result.error),
                       status: :unprocessable_content)
        end
      end

      private

      def launch_message(code)
        case code
        when :provider_not_configured
          "This game cannot be launched yet: no integration adapter is configured for its provider."
        when :game_unavailable
          "This game is not currently available."
        when :account_restricted
          "Your account is currently restricted and cannot start new sessions."
        when :wallet_unavailable
          "No usable wallet is available for this account."
        else
          "Unable to start a game session."
        end
      end
    end
  end
end
