# Test-only game integration adapter used to exercise the adapter contract and
# the provider-callback pipeline. It is never registered in the production
# registry: see config/initializers/game_providers.rb.
module TestAdapters
  class FakeAdapter < Games::Adapters::BaseAdapter
    def provider_key = "fake-provider"

    def integration_version = "1.0.0"

    def capabilities
      { launch: true, callbacks: true, transactions: true, currencies: %w[VCR] }
    end

    def launch_session(user:, game:, wallet:, locale: "en", ip: nil)
      Games::Adapters::Result.success(
        launch_url: "https://fake.example/play/#{game.slug}",
        provider_session_ref: "fake-ref-#{game.slug}-#{SecureRandom.hex(4)}",
        expires_at: 1.hour.from_now
      )
    end

    def verify_callback!(raw_body:, headers:)
      # Contract for tests: a body is "signed" when it starts with "signed:".
      ActiveSupport::SecurityUtils.secure_compare(raw_body.to_s[0, 7], "signed:")
    end

    def handle_event(event)
      wager = (event.payload["wager"] || 100).to_i
      Games::Adapters::Result.success(
        postings: [
          {
            wallet_id: event.game_session&.wallet_id,
            amount_minor: -wager,
            kind: :bet,
            idempotency_key: "fake-bet-#{event.external_id}",
            description: "Wager processed by FakeAdapter"
          }
        ]
      )
    end

    def health
      Games::Adapters::Result.success(status: :healthy, detail: "Test adapter is healthy")
    end
  end
end