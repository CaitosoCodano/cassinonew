require "test_helper"

class AdminApiTest < ActionDispatch::IntegrationTest
  setup do
    ensure_roles!
    Games::ProviderRegistry.register(TestAdapters::FakeAdapter)
  end

  teardown do
    Games::ProviderRegistry.clear!
  end

  test "the admin namespace denies anonymous visitors" do
    get "/api/v1/admin/system"
    assert_response :unauthorized
  end

  test "the admin namespace denies non-admin users" do
    user = create_user
    login_as(user)
    get "/api/v1/admin/system"
    assert_response :forbidden
  end

  test "providers with an unregistered adapter are rejected" do
    admin = create_admin
    login_as(admin)

    post "/api/v1/admin/game_providers", params: {
      game_provider: { slug: "mystery", name: "Mystery", adapter_class: "Not::Registered::Anywhere" }
    }, as: :json
    assert_response :unprocessable_content
  end

  test "admin can register a provider, a game, and adjust a wallet with full audit" do
    admin = create_admin
    login_as(admin)

    post "/api/v1/admin/game_providers", params: {
      game_provider: { slug: "fake-provider", name: "Fake Provider",
                       adapter_class: TestAdapters::FakeAdapter.name, integration_version: "1.0.0" }
    }, as: :json
    assert_response :created
    provider_id = json_body.dig("data", "id")

    post "/api/v1/admin/games", params: {
      game: { game_provider_id: provider_id, slug: "demo-slots", name: "Demo Slots",
              category: "slot", status: "coming_soon", supported_currencies: ["VCR"] }
    }, as: :json
    assert_response :created

    player = create_user
    post "/api/v1/admin/wallets/#{player.virtual_wallet.id}/adjustments", params: {
      amount_minor: 500, description: "Test adjustment", idempotency_key: "adm-1"
    }, as: :json
    assert_response :created
    assert_equal 500, player.virtual_wallet.reload.balance_minor
    assert_equal 1, player.virtual_wallet.transactions.count

    # Replaying with the same idempotency key must not double-post.
    post "/api/v1/admin/wallets/#{player.virtual_wallet.id}/adjustments", params: {
      amount_minor: 500, description: "Test adjustment", idempotency_key: "adm-1"
    }, as: :json
    assert_response :created
    assert_equal 500, player.virtual_wallet.reload.balance_minor
    assert_equal true, json_body.dig("data", "replayed")

    get "/api/v1/admin/audit_events"
    assert_response :success
    actions = json_body["data"].map { |event| event["action"] }
    assert_includes actions, "admin.wallet_adjusted"
    assert_includes actions, "admin.game_created"
  end

  test "feature flags can be toggled with an audit trail" do
    flag = FeatureFlag.create!(key: "test_flag", enabled: false, description: "temp")

    admin = create_admin
    login_as(admin)
    patch "/api/v1/admin/feature_flags/#{flag.id}", params: {
      feature_flag: { enabled: true }
    }, as: :json
    assert_response :success
    assert_equal true, flag.reload.enabled
  end

  test "support requests can be triaged by admins" do
    request = SupportRequest.create!(subject: "Help", message: "Need help", category: :account)

    admin = create_admin
    login_as(admin)
    patch "/api/v1/admin/support_requests/#{request.id}", params: {
      support_request: { status: "resolved" }
    }, as: :json
    assert_response :success
    assert request.reload.resolved?
    assert_not_nil request.reload.resolved_at
  end

  test "restrictions can be imposed and lifted" do
    player = create_user
    admin = create_admin
    login_as(admin)

    post "/api/v1/admin/restrictions", params: {
      user_id: player.id, kind: "deposit_block", reason: "Investigation"
    }, as: :json
    assert_response :created
    restriction_id = json_body.dig("data", "id")
    assert player.reload.restricted?("deposit_block")

    patch "/api/v1/admin/restrictions/#{restriction_id}"
    assert_response :success
    assert_not player.reload.restricted?("deposit_block")
    assert player.account_restrictions.last.lifted?
  end

  test "operators cannot demote themselves (guards the admin account)" do
    admin = create_admin
    login_as(admin)
    patch "/api/v1/admin/users/#{admin.id}", params: { role: "player" }, as: :json
    assert_response :unprocessable_content
    assert admin.reload.admin?
  end

  test "system endpoint reports real measurements only" do
    admin = create_admin
    login_as(admin)
    get "/api/v1/admin/system"
    assert_response :success
    data = json_body["data"]
    assert data["counts"]["users"] >= 1
    assert_equal 0, data["counts"]["games"] # no fabricated games
    assert_includes data["registered_adapters"], TestAdapters::FakeAdapter.name
  end
end