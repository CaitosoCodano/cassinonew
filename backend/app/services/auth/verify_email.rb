module Auth
  # Consumes an email-verification token and activates the account.
  class VerifyEmail
    Result = Struct.new(:user, :errors, keyword_init: true) do
      def success?
        errors.blank?
      end
    end

    def self.call(token:)
      record = EmailVerificationToken.find_usable_by_raw(token)
      return Result.new(user: nil, errors: ["This verification link is invalid or has expired."]) if record.nil?

      user = record.user
      user.verify_email!
      user.update!(status: :active) if user.pending?
      record.consume!

      Audit::Record.call(actor: user, action: "user.email_verified", auditable: user)

      Result.new(user: user, errors: [])
    end

    # Re-issues a verification token for an unverified user.
    def self.resend(user:)
      return false if user.email_verified?

      raw = EmailVerificationToken.issue!(user: user)
      AuthMailer.verify_email(user, raw).deliver_later
      true
    end
  end
end
