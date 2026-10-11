module Api
  module V1
    module ResponsibleGaming
      class LimitsController < ApplicationController
        before_action :authenticate_active_user!

        # GET /api/v1/responsible_gaming/limits
        def index
          render_collection(
            records: current_user.responsible_gaming_limits.order(:kind, :period),
            serializer: ResponsibleGamingLimitSerializer
          )
        end

        # POST /api/v1/responsible_gaming/limits
        def create
          limit = ::ResponsibleGaming::SetLimit.call(
            user: current_user,
            kind: params.require(:kind),
            period: params.fetch(:period, :daily),
            amount_minor: params[:amount_minor],
            duration_seconds: params[:duration_seconds],
            actor: current_user
          )

          render_resource(limit, serializer: ResponsibleGamingLimitSerializer, status: :created)
        rescue ::ResponsibleGaming::LimitError => e
          render_error(code: "limit_not_allowed", message: e.message, status: :unprocessable_content)
        end
      end
    end
  end
end
