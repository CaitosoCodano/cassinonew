require "test_helper"

class ResponsibleGamingControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_roles!
    @user = create_user
    login_as(@user)
  end

  test "a player can set a responsible-gaming limit" do
    post "/api/v1/responsible_gaming/limits", params: {
      kind: "deposit", period: "daily", amount_minor: 500
    }, as: :json
    assert_response :created
    assert_equal 500, json_body.dig("data", "amount_minor")
  end

  test "a player cannot loosen an existing limit" do
    post "/api/v1/responsible_gaming/limits", params: {
      kind: "deposit", period: "daily", amount_minor: 500
    }, as: :json
    assert_response :created

    post "/api/v1/responsible_gaming/limits", params: {
      kind: "deposit", period: "daily", amount_minor: 800
    }, as: :json
    assert_response :unprocessable_content
    assert_equal "limit_not_allowed", json_body.dig("error", "code")
  end

  test "limits are listed for the current account" do
    post "/api/v1/responsible_gaming/limits", params: {
      kind: "wager", period: "weekly", amount_minor: 1000
    }, as: :json

    get "/api/v1/responsible_gaming/limits"
    assert_response :success
    assert_equal 1, json_body["data"].size
    assert_equal "wager", json_body.dig("data", 0, "kind")
  end

  test "self-exclusion revokes the session immediately" do
    post "/api/v1/responsible_gaming/self_exclusion", params: { duration_days: 30 }, as: :json
    assert_response :created

    get "/api/v1/account"
    assert_response :unauthorized
    assert_equal 0, @user.sessions.active_now.count
  end

  test "restrictions summary is available" do
    get "/api/v1/responsible_gaming/restrictions"
    assert_response :success
    assert_empty json_body["data"]
  end
end