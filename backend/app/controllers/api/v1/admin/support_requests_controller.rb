module Api
  module V1
    module Admin
      class SupportRequestsController < BaseController
        # GET /api/v1/admin/support_requests
        def index
          scope = SupportRequest.includes(:user, :assigned_to).recent
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(category: params[:category]) if params[:category].present?
          scope = scope.where(priority: params[:priority]) if params[:priority].present?

          records, meta = paginate(scope)
          render_collection(records: records, serializer: SupportRequestSerializer, meta: meta)
        end

        # PATCH /api/v1/admin/support_requests/:id
        def update
          support_request = SupportRequest.find(params[:id])
          support_request.assign_attributes(request_params)
          support_request.resolved_at = Time.current if support_request.status_changed? && support_request.resolved?
          support_request.save!

          Audit::Record.call(actor: current_user, action: "admin.support_request_updated",
                             auditable: support_request,
                             metadata: request_params.to_h, request: request)

          render_resource(support_request, serializer: SupportRequestSerializer)
        end

        private

        def request_params
          params.require(:support_request).permit(:status, :priority, :assigned_to_id)
        end
      end
    end
  end
end
