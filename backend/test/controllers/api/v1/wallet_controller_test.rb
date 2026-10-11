require "test_helper"

class WalletControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_roles!
    @user = create_user
    login_as(@user)
  end

  test "wallet overview reconciles against the ledger" do
    get "/api/v1/wallet"
    assert_response :success
    data = json_body["data"]

    assert_equal 1, data["wallets"].size
    assert_equal "virtual", data.dig("wallets", 0, "kind")
    assert_equal true, data.dig("reconciliation", 0, "consistent")
    assert_equal 0, data.dig("reconciliation", 0, "discrepancy_minor")
  end

  test "transaction history is empty before any activity" do
    get "/api/v1/wallet/transactions"
    assert_response :success
    assert_empty json_body["data"]
    assert_equal 0, json_body.dig("meta", "total")
  end

  test "a user only ever sees their own transactions" do
    other = create_user(email: "other@example.com")
    Ledger::Post.call(wallet: other.virtual_wallet, amount_minor: 5_000, kind: :bonus)

    get "/api/v1/wallet/transactions"
    assert_empty json_body["data"]
  end

  test "deposits and withdrawals are explicitly unavailable" do
    post "/api/v1/wallet/deposits", params: { amount: 100 }, as: :json
    assert_response :not_implemented
    assert_equal "not_implemented", json_body.dig("error", "code")

    post "/api/v1/wallet/withdrawals", params: { amount: 10 }, as: :json
    assert_response :not_implemented
  end

  test "the ledger endpoint is read-only and reflects real postings" do
    Ledger::Post.call(wallet: @user.virtual_wallet, amount_minor: 250, kind: :bonus)

    get "/api/v1/wallet/ledger"
    assert_response :success
    assert_equal 1, json_body["data"].size
    assert_equal 250, json_body.dig("data", 0, "amount_minor")
    assert_equal 250, json_body.dig("data", 0, "balance_after_minor")
  end
end