module Api
  module V1
    module Auth
      class EmailVerificationsController < ApplicationController
        # POST /api/v1/auth/email/verify
        def create
          result = ::Auth::VerifyEmail.call(token: params.require(:token))

          if result.success?
            render json: { data: { email_verified: true } }
          else
            render_error(code: "verification_failed", message: result.errors.first,
                         status: :unprocessable_content)
          end
        end

        # POST /api/v1/auth/email/resend
        def resend
          authenticate_user!
          return if performed?

          if current_user.email_verified?
            render json: { data: { email_verified: true, message: "Your email is already verified." } }
          else
            ::Auth::VerifyEmail.resend(user: current_user)
            render json: { data: { email_verified: false, message: "Verification email sent." } },
                   status: :accepted
          end
        end
      end
    end
  end
end
