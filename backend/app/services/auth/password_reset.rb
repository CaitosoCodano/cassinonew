module Auth
  # Password reset: request + perform.
  #
  # The request step NEVER reveals whether an email exists (always returns
  # success). Tokens are single-use, expire, and are stored as digests only.
  module PasswordReset
    class Request
      def self.call(email:, ip: nil)
        user = User.find_by_email(email)
        if user && !user.closed?
          token = PasswordResetToken.issue!(user: user, ip: ip)
          AuthMailer.reset_password(user, token).deliver_later
          Audit::Record.call(actor: user, action: "user.password_reset_requested",
                             auditable: user, ip: ip)
        end

        # Always report success to prevent account enumeration.
        true
      end
    end

    class Perform
      Result = Struct.new(:user, :errors, keyword_init: true) do
        def success?
          errors.blank?
        end
      end

      def self.call(token:, password:, password_confirmation: nil)
        record = PasswordResetToken.find_usable_by_raw(token)
        return Result.new(user: nil, errors: ["This reset link is invalid or has expired."]) if record.nil?

        user = record.user
        if user.update(password: password, password_confirmation: password_confirmation.presence || password)
          record.consume!
          # Security: invalidate every existing session after a password change.
          user.sessions.active_now.find_each(&:revoke!)
          Audit::Record.call(actor: user, action: "user.password_reset_completed", auditable: user)
          Result.new(user: user, errors: [])
        else
          Result.new(user: nil, errors: user.errors.full_messages)
        end
      end
    end
  end
end
