require "test_helper"

class GamesLobbyTest < ActionDispatch::IntegrationTest
  setup do
    ensure_roles!
    Games::ProviderRegistry.register(TestAdapters::FakeAdapter)
  end

  teardown do
    Games::ProviderRegistry.clear!
  end

  test "the lobby is empty with honest meta when no games are registered" do
    get "/api/v1/games"
    assert_response :success
    assert_empty json_body["data"]
    assert_equal({ "page" => 1, "per_page" => 20, "total" => 0, "total_pages" => 0, "available" => false,
                   "registered" => 0, "providers_available" => 0 }, json_body["meta"])
  end

  test "provider list is empty until a provider is registered" do
    get "/api/v1/game_providers"
    assert_response :success
    assert_empty json_body["data"]
  end

  test "categories are enumerated with honest zero counts" do
    get "/api/v1/game_categories"
    assert_response :success
    assert json_body["data"].present?
    assert json_body["data"].all? { |category| category["count"].zero? }
  end

  test "inactive providers and hidden games never reach the public lobby" do
    provider = create_provider(slug: "dormant", status: :inactive)
    create_game(provider: provider, slug: "secret", status: :hidden)

    # provider advertised by accident
    other_provider = create_provider(slug: "active-but-hidden-game")
    create_game(provider: other_provider, slug: "not-released", status: :coming_soon)

    get "/api/v1/games"
    assert_empty json_body["data"]
    assert_equal false, json_body.dig("meta", "available")

    get "/api/v1/game_providers"
    assert_equal 1, json_body["data"].size
  end

  test "an active game from an active provider is listed as playable" do
    provider = create_provider
    create_game(provider: provider, slug: "demo-slot", name: "Demo Slot")

    get "/api/v1/games"
    assert_response :success
    assert_equal 1, json_body["data"].size
    assert json_body.dig("data", 0, "playable")
    assert_equal true, json_body.dig("meta", "available")

    get "/api/v1/games/#{json_body['data'][0]['id']}"
    assert_response :success
  end

  test "the lobby search ignores case" do
    provider = create_provider
    create_game(provider: provider, slug: "dragon_fortune", name: "Dragon Fortune")
    create_game(provider: provider, slug: "buffalo_fortune", name: "Buffalo Fortune")

    # SQLite folds ASCII case inside LIKE; PostgreSQL does not. The query has
    # to lower both sides for the result to be the same on either engine.
    { "dragon" => "Dragon Fortune", "DRAGON" => "Dragon Fortune",
      "DrAgOn" => "Dragon Fortune", "bUFFalo" => "Buffalo Fortune",
      "FORTUNE" => nil }.each do |query, expected_name|
      get "/api/v1/games", params: { q: query }
      assert_response :success

      # "fortune" is in both titles, so it narrows to both rather than one.
      expected = expected_name ? 1 : 2
      assert_equal expected, json_body["data"].size, "wrong match count for #{query.inspect}"
      assert_equal expected_name, json_body["data"].first&.dig("name") if expected_name
    end
  end

  test "the lobby search escapes wildcard characters" do
    provider = create_provider
    create_game(provider: provider, slug: "dragon_fortune", name: "Dragon Fortune")
    create_game(provider: provider, slug: "buffalo_fortune", name: "Buffalo Fortune")

    get "/api/v1/games", params: { q: "%" }
    assert_response :success
    assert_empty json_body["data"]
  end

  test "launching a game without a configured adapter reports provider_not_configured" do
    user = create_user
    login_as(user)

    provider = create_provider(adapter_class: nil, integration_version: nil)
    game = create_game(provider: provider)

    post "/api/v1/games/#{game.id}/sessions"
    assert_response :unprocessable_content
    assert_equal "provider_not_configured", json_body.dig("error", "code")
  end
end