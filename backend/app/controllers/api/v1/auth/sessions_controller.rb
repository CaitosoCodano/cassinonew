module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        MESSAGES = {
          invalid_credentials: "Invalid email or password.",
          locked: "This account is temporarily locked. Please try again later.",
          suspended: "This account is not available.",
          restricted: "This account is currently restricted."
        }.freeze

        # GET /api/v1/auth/session -> who am I?
        def show
          if current_user
            render json: { data: UserSerializer.one(current_user) }
          else
            head :no_content
          end
        end

        # POST /api/v1/auth/login
        def create
          result = ::Auth::Login.call(
            email: params.require(:email),
            password: params.require(:password),
            ip: request.remote_ip,
            user_agent: request.user_agent
          )

          if result.success?
            store_session_cookie(result.session, result.raw_token)
            Audit::Record.call(actor: result.user, action: "session.created",
                               auditable: result.session, ip: request.remote_ip,
                               user_agent: request.user_agent)
            render json: { data: UserSerializer.one(result.user) }, status: :created
          else
            render_error(code: result.error.to_s,
                         message: MESSAGES.fetch(result.error, "Unable to sign in."),
                         status: :unauthorized)
          end
        end

        # DELETE /api/v1/auth/logout
        def destroy
          ::Auth::Logout.call(session: current_session)
          clear_session_cookie
          head :no_content
        end

        # DELETE /api/v1/auth/logout_all
        def destroy_all
          authenticate_user!
          return if performed?

          ::Auth::Logout.call(user: current_user, all: true)
          clear_session_cookie
          head :no_content
        end
      end
    end
  end
end
