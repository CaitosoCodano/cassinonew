module Api
  module V1
    class AccountController < ApplicationController
      before_action :authenticate_active_user!

      # GET /api/v1/account
      def show
        render json: {
          data: {
            user: UserSerializer.one(current_user),
            profile: ProfileSerializer.one(current_user.profile),
            wallets: WalletSerializer.many(current_user.wallets.order(:kind, :currency)),
            restrictions: AccountRestrictionSerializer.many(
              current_user.account_restrictions.active_now.order(:starts_at)
            ),
            limits: ResponsibleGamingLimitSerializer.many(
              current_user.responsible_gaming_limits.current.order(:kind)
            ),
            verification: {
              email_verified: current_user.email_verified?,
              identity_status: current_user.profile&.identity_verification_status || "not_started"
            }
          }
        }
      end

      # PATCH /api/v1/account/profile
      def update
        profile = current_user.profile || current_user.build_profile

        if profile.update(profile_params)
          render json: { data: ProfileSerializer.one(profile) }
        else
          render_error(code: "update_failed", message: "Could not update your profile.",
                       status: :unprocessable_content, details: profile.errors.full_messages)
        end
      end

      # PATCH /api/v1/account/password
      def update_password
        unless current_user.authenticate(params.require(:current_password))
          return render_error(code: "invalid_password", message: "Your current password is incorrect.",
                              status: :unprocessable_content)
        end

        if current_user.update(password: params.require(:password),
                               password_confirmation: params[:password_confirmation].presence || params.require(:password))
          # Keep the caller signed in; revoke every other session.
          current_session_record = current_session
          current_user.sessions.active_now.where.not(id: current_session_record&.id).find_each(&:revoke!)

          Audit::Record.call(actor: current_user, action: "user.password_changed",
                             auditable: current_user, request: request)
          render json: { data: { message: "Password updated." } }
        else
          render_error(code: "update_failed", message: "Could not update your password.",
                       status: :unprocessable_content, details: current_user.errors.full_messages)
        end
      end

      private

      def profile_params
        source = params[:profile].present? ? params.require(:profile) : params
        source.permit(:display_name, :first_name, :last_name, :country_code, :phone, :locale,
                      :date_of_birth, :marketing_opt_in)
      end
    end
  end
end
