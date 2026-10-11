module Api
  module V1
    module ResponsibleGaming
      class SelfExclusionsController < ApplicationController
        before_action :authenticate_active_user!

        # POST /api/v1/responsible_gaming/self_exclusion
        def create
          restriction = ::ResponsibleGaming::SelfExclude.call(
            user: current_user,
            duration_days: params[:duration_days],
            reason: params[:reason],
            actor: current_user,
            request: request
          )

          # Sessions are revoked by the service; clear the client cookie too.
          clear_session_cookie

          render_resource(restriction, serializer: AccountRestrictionSerializer, status: :created)
        end
      end
    end
  end
end
