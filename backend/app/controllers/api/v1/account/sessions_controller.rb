module Api
  module V1
    module Account
      class SessionsController < ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/account/sessions
        def index
          sessions = current_user.sessions.order(created_at: :desc)
          render_collection(
            records: sessions,
            serializer: SessionSerializer,
            meta: { active_count: current_user.sessions.active_now.count },
            current_session_id: current_session&.id
          )
        end

        # DELETE /api/v1/account/sessions/:id
        def destroy
          target = current_user.sessions.find(params[:id])
          is_current = target.id == current_session&.id
          target.revoke!

          Audit::Record.call(actor: current_user, action: "session.revoked",
                             auditable: target, request: request)

          if is_current
            clear_session_cookie
            head :no_content
          else
            head :no_content
          end
        end
      end
    end
  end
end
