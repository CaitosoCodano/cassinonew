require "test_helper"

class WalletTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "one virtual wallet per user and currency" do
    user = create_user
    assert_equal 1, user.wallets.virtual.size

    user.wallets.create(kind: :virtual, currency: "VCR")
    assert user.wallets.count == 1
  end

  test "real money wallet is separate from virtual" do
    user = create_user
    real = user.wallets.create!(kind: :real, currency: "EUR")
    assert real.real?
    assert_not real.virtual?
  end

  test "usable? is false for frozen wallets" do
    user = create_user
    wallet = user.virtual_wallet
    wallet.update!(status: :frozen)
    assert_not wallet.usable?
  end

  test "balance rejects negative values" do
    user = create_user
    wallet = user.virtual_wallet
    assert_not wallet.update(balance_minor: -1)
    assert_includes wallet.errors[:balance_minor].to_s, "greater than or equal to 0"
  end
end