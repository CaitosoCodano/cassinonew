require "test_helper"

# The admin game console changes the payout every player is exposed to, so the
# permission boundary and the validation are tested explicitly.
class AdminGameConfigTest < ActionDispatch::IntegrationTest
  include SupportHelpers

  setup do
    @admin = create_admin
    @player = create_user
  end

  # --- authorisation --------------------------------------------------------

  test "a guest cannot read the game configuration" do
    get "/api/v1/admin/game_config"
    assert_response :unauthorized
  end

  test "a normal player cannot read the game configuration" do
    login_as(@player)

    get "/api/v1/admin/game_config"
    assert_response :forbidden
  end

  test "a normal player cannot change the return to player" do
    login_as(@player)

    patch "/api/v1/admin/game_config", params: { config: { user_rtp_percent: 99 } }, as: :json
    assert_response :forbidden
    assert_equal Games::Config::DEFAULTS["user_rtp_percent"], Games::Config["user_rtp_percent"]
  end

  # --- reading --------------------------------------------------------------

  test "an admin reads the current configuration with its limits" do
    login_as(@admin)

    get "/api/v1/admin/game_config"
    assert_response :success

    config = json_body.dig("data", "config")
    assert_equal Games::Config::DEFAULTS["user_rtp_percent"], config["user_rtp_percent"]

    limits = json_body.dig("data", "limits")
    assert_equal [Games::Config::LIMITS["user_rtp_percent"].min, Games::Config::LIMITS["user_rtp_percent"].max],
                 limits["user_rtp_percent"]
  end

  test "the configuration response lists registered titles" do
    login_as(@admin)
    get "/api/v1/admin/game_config"
    assert_response :success

    assert_includes json_body.dig("data", "registry"), "dragon_fortune"
    assert_includes json_body.dig("data", "registry"), "buffalo_fortune"
  end

  # --- writing --------------------------------------------------------------

  test "an admin can change the return to player and it takes effect immediately" do
    login_as(@admin)

    patch "/api/v1/admin/game_config", params: { config: { user_rtp_percent: 0.5 } }, as: :json
    assert_response :success
    assert_equal 0.5, Games::Config["user_rtp_percent"]
  ensure
    Games::Config.update!("user_rtp_percent" => Games::Config::DEFAULTS["user_rtp_percent"])
  end

  test "an admin can toggle the buy bonus" do
    login_as(@admin)

    patch "/api/v1/admin/game_config", params: { config: { buy_bonus_enabled: false } }, as: :json
    assert_response :success
    assert_equal false, Games::Config["buy_bonus_enabled"]
  ensure
    Games::Config.update!("buy_bonus_enabled" => true)
  end

  test "an out-of-range value is rejected and leaves the stored value untouched" do
    login_as(@admin)
    before = Games::Config["user_rtp_percent"]

    patch "/api/v1/admin/game_config", params: { config: { user_rtp_percent: 5000 } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_config", json_body.dig("error", "code")
    assert_equal "user_rtp_percent", json_body.dig("error", "details", "field")
    assert_equal before, Games::Config["user_rtp_percent"]
  end

  test "a non-numeric value is rejected" do
    login_as(@admin)

    patch "/api/v1/admin/game_config", params: { config: { user_rtp_percent: "loads" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "a minimum bet above the maximum bet is rejected" do
    login_as(@admin)

    patch "/api/v1/admin/game_config",
          params: { config: { min_bet_minor: 5_000, max_bet_minor: 1_000 } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "min_bet_minor", json_body.dig("error", "details", "field")
  end

  test "an unknown setting is rejected rather than silently stored" do
    login_as(@admin)

    patch "/api/v1/admin/game_config", params: { config: { secret_backdoor: true } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "secret_backdoor", json_body.dig("error", "details", "field")
  end

  # --- auditing -------------------------------------------------------------

  test "a configuration change is written to the audit log" do
    login_as(@admin)

    assert_difference -> { AuditEvent.where(action: "admin.game_config_updated").count }, 1 do
      patch "/api/v1/admin/game_config", params: { config: { user_rtp_percent: 0.4 } }, as: :json
    end

    event = AuditEvent.where(action: "admin.game_config_updated").last
    assert_equal @admin.id, event.actor_id
    assert_equal 0.4, event.metadata.dig("config", "user_rtp_percent")
  ensure
    Games::Config.update!("user_rtp_percent" => Games::Config::DEFAULTS["user_rtp_percent"])
  end

  # --- RTP measurement ------------------------------------------------------

  test "the rtp report measures the real maths rather than echoing the setting" do
    login_as(@admin)

    get "/api/v1/admin/game_config/rtp", params: { spins: 1_000 }
    assert_response :success

    entries = json_body.dig("data", "games")
    assert_equal Games::Registry.slugs.sort, entries.map { |e| e["slug"] }.sort

    entries.each do |entry|
      assert_operator entry["rtp_percent"], :>=, 0
      assert_operator entry["margin_error_percent"], :>, 0, "a report must carry its error bar"
      assert_operator entry["scale"], :>, 0
    end
  end

  test "the rtp report is capped so a huge request cannot stall the server" do
    login_as(@admin)

    get "/api/v1/admin/game_config/rtp", params: { spins: 10_000_000 }
    assert_response :success
    assert_operator json_body.dig("data", "spins"), :<=, 100_000
  end

  test "a player cannot trigger a simulation" do
    login_as(@player)

    get "/api/v1/admin/game_config/rtp"
    assert_response :forbidden
  end
end