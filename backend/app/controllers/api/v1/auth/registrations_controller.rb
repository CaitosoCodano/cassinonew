module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        # POST /api/v1/auth/register
        #
        # Creating the account also signs the player in. Leaving them logged
        # out meant landing on the "check your email" screen with no session,
        # so the wallet, the lobby and the games were all unreachable until they
        # came back and typed the password they had just chosen.
        def create
          result = ::Auth::Register.call(
            email: params.require(:email),
            password: params.require(:password),
            password_confirmation: params[:password_confirmation],
            locale: params[:locale],
            country_code: params[:country_code],
            marketing_opt_in: ActiveModel::Type::Boolean.new.cast(params[:marketing_opt_in]),
            ip: request.remote_ip
          )

          if result.success?
            start_session_for(result.user)
            render_resource(result.user, serializer: UserSerializer, status: :created)
          else
            render_error(code: "registration_failed", message: "We could not create your account.",
                         status: :unprocessable_content, details: result.errors)
          end
        end

        private

        # Issues a real session for the freshly created user.
        def start_session_for(user)
          login = ::Auth::Login.issue_for(
            user: user,
            ip: request.remote_ip,
            user_agent: request.user_agent
          )
          return unless login.success?

          store_session_cookie(login.session, login.raw_token)
          Audit::Record.call(
            actor: user,
            action: "session.created",
            auditable: login.session,
            metadata: { reason: "registration" },
            request: request
          )
        end
      end
    end
  end
end
