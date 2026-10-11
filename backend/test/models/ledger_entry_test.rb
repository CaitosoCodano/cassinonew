require "test_helper"

class LedgerEntryTest < ActiveSupport::TestCase
  setup do
    ensure_roles!
    @user = create_user
    @wallet = @user.virtual_wallet
  end

  test "persisted entries are read-only" do
    result = Ledger::Post.call(wallet: @wallet, amount_minor: 500, kind: :bonus)
    entry = @wallet.ledger_entries.first

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      entry.update!(amount_minor: 999)
    end

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      entry.destroy!
    end

    assert_equal 500, entry.reload.amount_minor
  end

  test "sequence is unique per wallet and monotonically increases" do
    Ledger::Post.call(wallet: @wallet, amount_minor: 100, kind: :adjustment)
    Ledger::Post.call(wallet: @wallet, amount_minor: -40, kind: :adjustment)

    sequences = @wallet.ledger_entries.order(:sequence).pluck(:sequence)
    assert_equal [1, 2], sequences
  end

  test "every transaction has exactly one ledger entry" do
    result = Ledger::Post.call(wallet: @wallet, amount_minor: 100, kind: :adjustment)
    assert_equal 1, result.transaction.ledger_entries.count
  end
end