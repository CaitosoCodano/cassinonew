module Api
  module V1
    module Auth
      class PasswordsController < ApplicationController
        # POST /api/v1/auth/password/forgot
        def create
          ::Auth::PasswordReset::Request.call(email: params.require(:email), ip: request.remote_ip)
          # Always the same response: never reveal whether the email exists.
          render json: {
            data: { message: "If an account exists for that email address, a reset link has been sent." }
          }, status: :accepted
        end

        # POST /api/v1/auth/password/reset
        def update
          result = ::Auth::PasswordReset::Perform.call(
            token: params.require(:token),
            password: params.require(:password),
            password_confirmation: params[:password_confirmation]
          )

          if result.success?
            head :no_content
          else
            render_error(code: "reset_failed", message: "We could not reset your password.",
                         status: :unprocessable_content, details: result.errors)
          end
        end
      end
    end
  end
end
