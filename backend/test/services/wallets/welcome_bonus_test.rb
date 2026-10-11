require "test_helper"

# A new account must be able to actually play. The welcome bonus is what makes
# that true, so it gets its own coverage rather than being folded into a
# balance assertion somewhere else.
class Wallets::WelcomeBonusTest < ActiveSupport::TestCase
  include SupportHelpers

  setup do
    # The suite runs with the bonus disabled so other tests can assert exact
    # balances from zero; this file opts back in explicitly.
    @original = ENV["WELCOME_BONUS_MINOR"]
    ENV["WELCOME_BONUS_MINOR"] = "100_000"
  end

  teardown do
    ENV["WELCOME_BONUS_MINOR"] = @original
  end

  test "a new account is granted play money so it can bet" do
    user = create_user

    assert_equal 100_000, user.virtual_wallet.reload.balance_minor
  end

  test "the grant is posted through the ledger, not written onto the balance" do
    user = create_user
    transaction = user.virtual_wallet.transactions.order(:id).last

    assert_equal "bonus", transaction.kind
    assert_equal 100_000, transaction.amount_minor
    assert_equal 0, transaction.balance_before_minor
    assert_equal 100_000, transaction.balance_after_minor
    assert_equal "Welcome bonus", transaction.description
    assert_equal 1, user.virtual_wallet.ledger_entries.count
  end

  test "provisioning again does not grant a second bonus" do
    user = create_user

    3.times { Wallets::Provision.call(user: user) }

    assert_equal 100_000, user.virtual_wallet.reload.balance_minor
    assert_equal 1, user.virtual_wallet.transactions.count
  end

  test "the bonus is skipped when the configured amount is zero" do
    ENV["WELCOME_BONUS_MINOR"] = "0"
    user = create_user

    assert_equal 0, user.virtual_wallet.reload.balance_minor
    assert_empty user.virtual_wallet.transactions
  end

  test "an unparseable amount falls back to the default rather than crashing" do
    ENV["WELCOME_BONUS_MINOR"] = "not-a-number"

    assert_equal Wallets::Provision::WELCOME_BONUS_MINOR_DEFAULT, Wallets::Provision.welcome_bonus_minor
  end

  test "a brand new account can place a bet immediately" do
    user = create_user
    game = create_game(provider: create_provider(slug: "internal", adapter_class: nil),
                       slug: "dragon_fortune", name: "Dragon Fortune",
                       min_bet_minor: 100, max_bet_minor: 1_000_000)

    result = Games::PlayService.new(game: game, user: user, wallet: user.virtual_wallet, bet_minor: 100).call

    assert_operator result.balance_minor, :<=, 100_000
    assert_operator result.balance_minor, :>=, 0
  end
end