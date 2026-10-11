require "test_helper"

class LedgerPostTest < ActiveSupport::TestCase
  setup do
    ensure_roles!
    @user = create_user
    @wallet = @user.virtual_wallet
  end

  test "credits the wallet atomically and writes the ledger" do
    result = Ledger::Post.call(wallet: @wallet, amount_minor: 250, kind: :bonus)

    assert_not result.replayed?
    assert_equal 250, @wallet.reload.balance_minor
    assert result.transaction.completed?
    assert result.transaction.credit?

    entry = @wallet.ledger_entries.first
    assert_equal 250, entry.amount_minor
    assert_equal 250, entry.balance_after_minor
    assert_equal 1, entry.sequence
  end

  test "allows debits covered by the balance" do
    Ledger::Post.call(wallet: @wallet, amount_minor: 1000, kind: :bonus)
    result = Ledger::Post.call(wallet: @wallet, amount_minor: -400, kind: :bet)

    assert result.transaction.debit?
    assert_equal 600, @wallet.reload.balance_minor
    assert_equal 2, @wallet.transactions.count # both ledger steps kept as history
  end

  test "rejects debits exceeding the balance" do
    assert_raises(Ledger::InsufficientFunds) do
      Ledger::Post.call(wallet: @wallet, amount_minor: -10, kind: :bet)
    end
    assert_equal 0, @wallet.reload.balance_minor
    assert_equal 0, @wallet.transactions.count
  end

  test "rejects frozen wallets" do
    @wallet.update!(status: :frozen)
    assert_raises(Ledger::WalletNotUsable) do
      Ledger::Post.call(wallet: @wallet, amount_minor: 10, kind: :bonus)
    end
  end

  test "rejects zero and non-integer amounts" do
    assert_raises(Ledger::InvalidAmount) { Ledger::Post.call(wallet: @wallet, amount_minor: 0, kind: :bonus) }
    assert_raises(Ledger::InvalidAmount) { Ledger::Post.call(wallet: @wallet, amount_minor: 1.5, kind: :bonus) }
  end

  test "is idempotent using an idempotency key" do
    first = Ledger::Post.call(wallet: @wallet, amount_minor: 500, kind: :bonus,
                              idempotency_key: "bonus-abc")
    second = Ledger::Post.call(wallet: @wallet, amount_minor: 500, kind: :bonus,
                               idempotency_key: "bonus-abc")

    assert second.replayed?
    assert_equal first.transaction.id, second.transaction.id
    assert_equal 500, @wallet.reload.balance_minor
    assert_equal 1, @wallet.transactions.count
    assert_equal 1, @wallet.ledger_entries.count
  end

  test "different keys create separate transactions" do
    Ledger::Post.call(wallet: @wallet, amount_minor: 100, kind: :bonus, idempotency_key: "k1")
    Ledger::Post.call(wallet: @wallet, amount_minor: 100, kind: :bonus, idempotency_key: "k2")
    assert_equal 200, @wallet.reload.balance_minor
    assert_equal 2, @wallet.transactions.count
  end

  test "does not accept a client-supplied balance" do
    parameters = Ledger::Post.method(:call).parameters
    names = parameters.flat_map { |(kind, name)| kind == :key ? name : [name] if name }
    assert_not_includes names, :balance
    assert_not_includes names, :balance_before_minor
    assert_not_includes names, :balance_after_minor
  end
end