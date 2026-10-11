require "test_helper"

module TestAdapters
  # A (misbehaving / compromised) adapter that tries to post money to a wallet
  # that does NOT belong to the callback's session user. The platform must
  # refuse the booking and leave both balances untouched.
  class WalletMismatchAdapter < FakeAdapter
    def handle_event(event)
      target_id = User.find_by(email: "outsider@example.com").virtual_wallet.id
      Games::Adapters::Result.success(
        postings: [{
          wallet_id: target_id,
          amount_minor: -999,
          kind: :bet,
          idempotency_key: "evil-#{event.external_id}"
        }]
      )
    end
  end
end

class GamesProviderCallbackProcessorTest < ActiveSupport::TestCase
  setup do
    ensure_roles!
    Games::ProviderRegistry.register(TestAdapters::FakeAdapter)

    @provider = create_provider
    @user = create_user
    Ledger::Post.call(wallet: @user.virtual_wallet, amount_minor: 10_000, kind: :bonus, idempotency_key: "seed")
    @game = create_game(provider: @provider)
    @game_session = @user.game_sessions.create!(
      game: @game, wallet: @user.virtual_wallet, status: :active,
      provider_session_reference: "fake-ref-callback-1", started_at: Time.current
    )
  end

  teardown do
    Games::ProviderRegistry.clear!
  end

  def process(external_id:, body: "signed:{}", payload: {})
    Games::ProviderCallbackProcessor.call(
      provider: @provider,
      raw_body: body,
      headers: {},
      payload: payload,
      external_id: external_id,
      event_type: "bet"
    )
  end

  test "processes a signed bet event and moves money through the ledger" do
    result = process(external_id: "evt-1", payload: { wager: 100, provider_session_ref: "fake-ref-callback-1" })

    assert result.success?
    assert_equal :processed, result.status
    assert result.provider_event.signature_valid
    assert result.provider_event.processed?

    assert_equal 9_900, @user.virtual_wallet.reload.balance_minor
    bet = @user.transactions.where(kind: :bet).first
    assert_not_nil bet
    assert_equal(-100, bet.amount_minor)
    assert_equal 2, @user.transactions.count # setup credit + wager
  end

  test "is replay-safe: duplicate events are recorded once" do
    process(external_id: "evt-dup", payload: { wager: 100, provider_session_ref: "fake-ref-callback-1" })
    second = process(external_id: "evt-dup", payload: { wager: 100, provider_session_ref: "fake-ref-callback-1" })

    assert second.success?
    assert_equal :duplicate, second.status
    assert_equal 9_900, @user.virtual_wallet.reload.balance_minor
    assert_equal 2, @user.transactions.count # setup credit + one wager, no double-post
  end

  test "rejects unsigned callbacks and keeps them for the audit trail" do
    result = process(external_id: "evt-forged", body: "forged", payload: {})

    assert_not result.success?
    assert_equal :invalid_signature, result.error
    event = result.provider_event
    assert_not event.signature_valid
    assert event.rejected?
    assert_equal 10_000, @user.virtual_wallet.reload.balance_minor
  end

  test "refuses to touch wallets outside the session user's account" do
    outsider = create_user(email: "outsider@example.com")
    Ledger::Post.call(wallet: outsider.virtual_wallet, amount_minor: 5_000, kind: :bonus)

    Games::ProviderRegistry.register(TestAdapters::WalletMismatchAdapter)
    @provider.update!(adapter_class: TestAdapters::WalletMismatchAdapter.name)

    result = process(external_id: "evt-evil", payload: { wager: 100, provider_session_ref: "fake-ref-callback-1" })

    assert_not result.success?
    assert_equal :ledger_rejected, result.error
    assert_equal 10_000, @user.virtual_wallet.reload.balance_minor
    assert_equal 5_000, outsider.virtual_wallet.reload.balance_minor
  end
end