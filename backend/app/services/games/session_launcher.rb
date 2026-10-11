module Games
  # Creates a play session for a user on a game and delegates launch to the
  # provider's registered integration adapter.
  #
  # No adapter is bundled with this deployment, so in practice this returns a
  # `:provider_not_configured` failure -- which the lobby surfaces honestly.
  class SessionLauncher
    Result = Struct.new(:game_session, :launch_url, :error, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    def self.call(user:, game:, wallet: nil, ip: nil, user_agent: nil, locale: "en")
      return failure(:game_unavailable) unless game.playable?

      if user.restricted?
        return failure(:account_restricted)
      end

      provider = game.game_provider
      adapter_class = provider.adapter
      return failure(:provider_not_configured) if adapter_class.nil?

      wallet ||= user.virtual_wallet
      return failure(:wallet_unavailable) if wallet.nil? || !wallet.usable?

      game_session = GameSession.create!(
        user: user, game: game, wallet: wallet, status: :pending,
        ip_address: ip, user_agent: user_agent, expires_at: 1.hour.from_now
      )

      adapter = adapter_class.new(provider: provider)
      outcome = adapter.launch_session(user: user, game: game, wallet: wallet, locale: locale, ip: ip)

      if outcome.success?
        game_session.update!(
          status: :active,
          started_at: Time.current,
          provider_session_reference: outcome.data[:provider_session_ref]
        )
        Audit::Record.call(actor: user, action: "game_session.launched", auditable: game_session,
                           metadata: { provider: provider.slug, game: game.slug }, ip: ip)
        Result.new(game_session: game_session, launch_url: outcome.data[:launch_url], error: nil)
      else
        game_session.update!(
          status: :terminated, ended_at: Time.current,
          metadata: game_session.metadata.merge("launch_error" => outcome.error_code.to_s)
        )
        failure(outcome.error_code)
      end
    end

    def self.failure(code)
      Result.new(game_session: nil, launch_url: nil, error: code)
    end
    private_class_method :failure
  end
end
