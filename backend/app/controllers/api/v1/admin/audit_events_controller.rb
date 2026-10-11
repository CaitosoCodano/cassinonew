module Api
  module V1
    module Admin
      class AuditEventsController < BaseController
        # GET /api/v1/admin/audit_events
        # Filters: actor_id, event_action (NOT `action` -- that name collides with
        # Rails' routing params), auditable_type.
        def index
          scope = AuditEvent.includes(:actor).recent
          scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?
          scope = scope.where(action: params[:event_action]) if params[:event_action].present?
          scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?

          records, meta = paginate(scope)
          render_collection(records: records, serializer: AuditEventSerializer, meta: meta)
        end
      end
    end
  end
end
