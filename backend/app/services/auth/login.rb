module Auth
  # Verifies credentials and creates a server-side Session record. The raw
  # session token is returned to the caller and placed in an HttpOnly cookie by
  # the controller; only its digest is persisted.
  #
  # Includes lockout after repeated failures and a timing-attack mitigation so
  # that the response time does not reveal whether an email exists.
  class Login
    MAX_FAILED_ATTEMPTS = 5
    LOCKOUT_PERIOD = 15.minutes

    BLOCKING_RESTRICTIONS = %w[self_exclusion suspension ban cool_off].freeze

    Result = Struct.new(:user, :session, :raw_token, :error, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    def self.call(email:, password:, ip: nil, user_agent: nil, expires_in: nil)
      user = User.find_by_email(email)
      expires_in ||= Platform::SESSION_ABSOLUTE_TTL

      # Timing mitigation: always perform a bcrypt comparison.
      if user.nil?
        BCrypt::Password.new(dummy_digest) == password
        return failure(:invalid_credentials)
      end

      return failure(:locked) if user.locked? && user.locked_at > LOCKOUT_PERIOD.ago
      return failure(:suspended) if user.suspended? || user.closed?

      unless user.authenticate(password)
        register_failure(user)
        return failure(:invalid_credentials)
      end

      if blocking_restriction?(user)
        return failure(:restricted)
      end

      raw_token = SecureRandom.urlsafe_base64(32)
      session = user.sessions.create!(
        token_digest: Session.digest(raw_token),
        ip_address: ip,
        user_agent: user_agent,
        last_seen_at: Time.current,
        expires_at: expires_in.from_now
      )

      user.update!(failed_sign_in_attempts: 0, locked_at: nil, last_sign_in_at: Time.current)

      Audit::Record.call(actor: user, action: "user.signed_in", auditable: user, ip: ip, user_agent: user_agent)

      Result.new(user: user, session: session, raw_token: raw_token, error: nil)
    end

    # Issues a session for a user whose identity is already established.
    #
    # Used straight after registration, where creating the account already
    # proved the credentials. There is no window in which a caller can supply an
    # arbitrary user record and obtain a session for it: the only caller is the
    # registration controller, holding the record it just created.
    def self.issue_for(user:, ip: nil, user_agent: nil, expires_in: nil)
      return failure(:invalid_credentials) if user.nil?
      return failure(:suspended) if user.suspended? || user.closed?
      return failure(:restricted) if blocking_restriction?(user)

      expires_in ||= Platform::SESSION_ABSOLUTE_TTL

      raw_token = SecureRandom.urlsafe_base64(32)
      session = user.sessions.create!(
        token_digest: Session.digest(raw_token),
        ip_address: ip,
        user_agent: user_agent,
        last_seen_at: Time.current,
        expires_at: expires_in.from_now
      )

      user.update!(failed_sign_in_attempts: 0, locked_at: nil, last_sign_in_at: Time.current)

      Result.new(user: user, session: session, raw_token: raw_token, error: nil)
    end

    def self.failure(code)
      Result.new(user: nil, session: nil, raw_token: nil, error: code)
    end
    private_class_method :failure

    def self.register_failure(user)
      user.increment!(:failed_sign_in_attempts)
      user.update!(locked_at: Time.current) if user.failed_sign_in_attempts >= MAX_FAILED_ATTEMPTS
    end
    private_class_method :register_failure

    def self.blocking_restriction?(user)
      user.account_restrictions.active_now.any? { |r| BLOCKING_RESTRICTIONS.include?(r.kind.to_s) }
    end
    private_class_method :blocking_restriction?

    def self.dummy_digest
      @dummy_digest ||= BCrypt::Password.create("timing-attack-mitigation-placeholder").to_s
    end
    private_class_method :dummy_digest
  end
end
