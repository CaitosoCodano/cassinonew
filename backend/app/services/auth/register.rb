module Auth
  # Registers a new account: creates the user, profile, default wallet(s) and
  # an email-verification token, then enqueues the verification email.
  #
  # New accounts are created with status :pending and become :active once the
  # email is verified.
  class Register
    Result = Struct.new(:user, :errors, keyword_init: true) do
      def success?
        errors.blank?
      end
    end

    def self.call(email:, password:, password_confirmation: nil, locale: "en", country_code: nil,
                  marketing_opt_in: false, ip: nil)
      role = Role.default_by_name(Role::PLAYER)
      return Result.new(user: nil, errors: ["Player role is not configured"]) if role.nil?

      user = User.new(
        email: email,
        password: password,
        password_confirmation: password_confirmation.presence || password,
        role: role
      )

      if user.save
        create_related!(user, locale: locale, country_code: country_code, marketing_opt_in: marketing_opt_in)

        raw = EmailVerificationToken.issue!(user: user)
        AuthMailer.verify_email(user, raw).deliver_later

        Audit::Record.call(actor: user, action: "user.registered", auditable: user,
                           metadata: { email: user.email }, ip: ip)

        Result.new(user: user, errors: [])
      else
        Result.new(user: nil, errors: user.errors.full_messages)
      end
    end

    def self.create_related!(user, locale:, country_code:, marketing_opt_in:)
      user.create_profile!(
        locale: locale.presence || "en",
        country_code: country_code.presence&.upcase,
        marketing_opt_in: marketing_opt_in == true
      )
      Wallets::Provision.call(user: user)
    end
    private_class_method :create_related!
  end
end
