module Games
  # Validates and processes an inbound callback from a game provider.
  #
  # Security properties:
  #   * the adapter MUST verify the request signature (constant-time compare);
  #   * events are de-duplicated by external_id (unique index) -> replay-safe;
  #   * rejected and duplicate events are still persisted for the audit trail;
  #   * money movement is delegated to Ledger::Post, which is atomic and
  #     idempotent, and never trusts an amount supplied out-of-band.
  class ProviderCallbackProcessor
    Result = Struct.new(:status, :provider_event, :error, keyword_init: true) do
      def success?
        %i[processed duplicate].include?(status)
      end
    end

    def self.call(provider:, raw_body:, headers:, payload:, external_id:, event_type:)
      return Result.new(status: :rejected, error: :missing_external_id) if external_id.blank?

      existing = ProviderEvent.find_by(external_id: external_id)
      return Result.new(status: :duplicate, provider_event: existing) if existing

      adapter_class = provider.adapter
      signature_valid = adapter_class ? adapter_class.new(provider: provider)
                                                       .verify_callback!(raw_body: raw_body, headers: headers) : false

      event = ProviderEvent.new(
        game_provider: provider,
        event_type: event_type,
        external_id: external_id,
        payload: payload,
        signature_valid: signature_valid,
        processing_status: signature_valid ? :received : :rejected
      )
      event.game_session = find_session(payload)

      begin
        event.save!
      rescue ActiveRecord::RecordNotUnique
        return Result.new(status: :duplicate, provider_event: ProviderEvent.find_by(external_id: external_id))
      end

      unless signature_valid
        event.update!(error_message: "Invalid signature", processed_at: Time.current)
        return Result.new(status: :rejected, provider_event: event, error: :invalid_signature)
      end

      apply!(event, adapter_class, provider)
    end

    class << self
      private

      def find_session(payload)
        ref = payload["provider_session_ref"] || payload[:provider_session_ref]
        return nil if ref.blank?

        GameSession.find_by(provider_session_reference: ref)
      end

      def apply!(event, adapter_class, provider)
        adapter = adapter_class.new(provider: provider)
        outcome = adapter.handle_event(event)

        unless outcome.success?
          event.update!(processing_status: :rejected, error_message: outcome.error_message,
                        processed_at: Time.current)
          return Result.new(status: :rejected, provider_event: event, error: outcome.error_code)
        end

        postings = Array(outcome.data[:postings])
        postings.each { |posting| apply_posting!(event, posting) }

        event.update!(processing_status: :processed, processed_at: Time.current)
        Result.new(status: :processed, provider_event: event)
      rescue Ledger::Error => e
        event.update!(processing_status: :rejected, error_message: e.message, processed_at: Time.current)
        Result.new(status: :rejected, provider_event: event, error: :ledger_rejected)
      end

      def apply_posting!(event, posting)
        wallet = resolve_wallet(event, posting)
        raise Ledger::Error, "Unknown wallet in provider posting" if wallet.nil?

        Ledger::Post.call(
          wallet: wallet,
          amount_minor: posting[:amount_minor],
          kind: posting[:kind],
          idempotency_key: posting[:idempotency_key],
          description: posting[:description],
          provider: event.game_provider&.slug,
          external_reference: event.external_id,
          metadata: { provider_event_id: event.id }
        )
      end

      # A provider may only move money on a wallet belonging to the session's
      # user. This prevents a compromised provider from touching other accounts.
      def resolve_wallet(event, posting)
        return nil if event.game_session.nil?

        session_wallet = event.game_session.wallet
        requested_id = posting[:wallet_id]

        return session_wallet if requested_id.blank? || requested_id.to_i == session_wallet.id

        user_wallet = event.game_session.user.wallets.find_by(id: requested_id)
        user_wallet
      end
    end
  end
end
