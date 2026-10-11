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
      if role.nil?
        # Unseeded database. Every signup fails with a generic 422 and no clue
        # as to why, so say it loudly rather than returning a bare refusal.
        Rails.logger.error(
          "Registration refused: role #{Role::PLAYER.inspect} is missing. " \
          "Run `bin/rails db:seed`; a deployment that skipped seeding cannot accept accounts."
        )
        return Result.new(user: nil, errors: ["Account creation is temporarily unavailable"])
      end

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
        # Registration refusal is one of the few places a player gets no second
        # chance, and the reason is invisible outside the response body. Put it
        # in the log: a deployment where every signup returns 422 looks like a
        # routing fault until someone can read why.
        Rails.logger.info(
          "Registration refused for #{user.email.inspect}: #{user.errors.full_messages.join(', ')}"
        )
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
