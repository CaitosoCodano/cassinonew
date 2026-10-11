require "test_helper"

class LedgerReconcileTest < ActiveSupport::TestCase
  setup do
    ensure_roles!
    @user = create_user
    @wallet = @user.virtual_wallet
  end

  test "reports consistency after legitimate postings" do
    Ledger::Post.call(wallet: @wallet, amount_minor: 300, kind: :bonus)
    Ledger::Post.call(wallet: @wallet, amount_minor: -100, kind: :bet)

    report = Ledger::Reconcile.call(wallet: @wallet)
    assert report.consistent?
    assert_equal report.ledger_total_minor, report.wallet_balance_minor
  end

  test "flags drift between the wallet and the ledger" do
    Ledger::Post.call(wallet: @wallet, amount_minor: 300, kind: :bonus)
    @wallet.update_column(:balance_minor, 999) # simulated drift / tampering

    report = Ledger::Reconcile.call(wallet: @wallet)
    assert_not report.consistent?
    assert_equal 300, report.ledger_total_minor
    assert_equal 999, report.wallet_balance_minor
  end
end