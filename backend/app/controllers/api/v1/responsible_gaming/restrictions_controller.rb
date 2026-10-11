module Api
  module V1
    module ResponsibleGaming
      class RestrictionsController < ApplicationController
        before_action :authenticate_active_user!

        # GET /api/v1/responsible_gaming/restrictions
        def index
          render_collection(
            records: current_user.account_restrictions.order(created_at: :desc),
            serializer: AccountRestrictionSerializer,
            meta: { active_count: current_user.account_restrictions.active_now.count }
          )
        end
      end
    end
  end
end
