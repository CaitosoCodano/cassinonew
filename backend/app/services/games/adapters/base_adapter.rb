module Games
  module Adapters
    # === Game integration contract =========================================
    #
    # Every future casino game integration (whether a Ruby game server, an
    # external aggregator, or a first-party service) is integrated by
    # subclassing this adapter and registering it in the ProviderRegistry.
    #
    # A provider record (GameProvider) references the adapter by class name and
    # stores non-secret configuration in #config. Secrets are NEVER stored in
    # the database: adapters read them from Rails credentials or ENV.
    #
    # Subclasses MUST implement the abstract methods below. Unsupported optional
    # capabilities should set `capabilities[:<name>] = false` and raise
    # NotImplementedError from the corresponding method.
    #
    # Lifecycle:
    #
    #   1. launch_session  -> create/return a launch URL + provider session ref
    #   2. validate_session -> confirm a session is still authorised (per bet)
    #   3. handle_event     -> process provider -> platform events (bets/wins)
    #   4. health           -> report availability for the admin status board
    #
    # All money movement goes through Ledger::Post; adapters never mutate wallet
    # balances directly.
    class BaseAdapter
      class ConfigurationError < StandardError; end

      attr_reader :provider, :config

      # @param provider [GameProvider]
      # @param config [Hash] non-secret configuration from the provider record
      def initialize(provider:, config: {})
        @provider = provider
        @config = (provider&.config || {}).merge(config || {}).with_indifferent_access
      end

      # ----------------------------------------------------------------------
      # Identity / metadata
      # ----------------------------------------------------------------------

      # Stable, unique provider identifier, e.g. "ruby-crash-canary".
      def provider_key
        raise NotImplementedError, "#{self.class}#provider_key"
      end

      # Semver-ish string surfaced in the admin integration status board.
      def integration_version
        raise NotImplementedError, "#{self.class}#integration_version"
      end

      # Hash describing what this adapter supports, e.g.
      #   { currencies: %w[VCR], launch: true, callbacks: true, demo: false }
      def capabilities
        raise NotImplementedError, "#{self.class}#capabilities"
      end

      # Metadata for a single game (name, category, thumbnail, bet limits...).
      # @return [Games::Adapters::Result] data: Hash
      def game_metadata(game)
        Result.success(
          identifier: game.slug,
          name: game.name,
          category: game.category,
          thumbnail_url: game.thumbnail_url
        )
      end

      # ----------------------------------------------------------------------
      # Session lifecycle
      # ----------------------------------------------------------------------

      # Initialise a play session for a user on a game.
      # @return [Games::Adapters::Result] data: { launch_url:, provider_session_ref:, expires_at: }
      def launch_session(user:, game:, wallet:, locale: "en", ip: nil)
        raise NotImplementedError, "#{self.class}#launch_session"
      end

      # Re-validate an existing session (e.g. before accepting a bet callback).
      # @return [Games::Adapters::Result] data: { valid:, reason: }
      def validate_session(game_session)
        raise NotImplementedError, "#{self.class}#validate_session"
      end

      # ----------------------------------------------------------------------
      # Event / transaction handling
      # ----------------------------------------------------------------------

      # Verify the authenticity of an inbound provider request. Implementations
      # MUST use a constant-time comparison (e.g. ActiveSupport::SecurityUtils)
      # and MUST reject missing/invalid signatures.
      # @return [Boolean]
      def verify_callback!(raw_body:, headers:)
        raise NotImplementedError, "#{self.class}#verify_callback!"
      end

      # Translate + normalise an inbound provider event into platform actions.
      # Implementations should return a Result whose data describes the
      # transaction(s) to be applied by Games::ProviderCallbackProcessor.
      # @return [Games::Adapters::Result]
      def handle_event(event)
        raise NotImplementedError, "#{self.class}#handle_event"
      end

      # ----------------------------------------------------------------------
      # Availability
      # ----------------------------------------------------------------------

      # @return [Games::Adapters::Result] data: { status: :healthy|:degraded|:down, detail: String }
      def health
        Result.success(status: :unknown, detail: "Adapter does not implement health checks")
      end

      def available?
        provider.present? && provider.active?
      end

      private

      def require_config!(*keys)
        missing = keys.select { |key| config[key].blank? }
        return if missing.empty?

        raise ConfigurationError, "Missing provider configuration: #{missing.join(', ')}"
      end
    end
  end
end
