module Api
  module V1
    module Account
      class ActivityController < ApplicationController
        before_action :authenticate_active_user!

        # GET /api/v1/account/activity
        def index
          scope = current_user.audit_events.recent
          records, meta = paginate(scope)
          render_collection(records: records, serializer: AuditEventSerializer, meta: meta)
        end
      end
    end
  end
end
