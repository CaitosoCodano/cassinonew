require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    ensure_roles!
    @user = create_user
    login_as(@user)
  end

  test "shows a real account summary" do
    get "/api/v1/account"
    assert_response :success
    data = json_body["data"]

    assert_equal @user.email, data.dig("user", "email")
    assert_equal 1, data["wallets"].size
    assert_equal 0, data.dig("wallets", 0, "balance_minor")
    assert_equal({ "email_verified" => true, "identity_status" => "not_started" }, data["verification"])
    assert_empty data["restrictions"]
    assert_empty data["limits"]
  end

  test "updates the profile" do
    patch "/api/v1/account/profile", params: {
      profile: { display_name: "Goldie", country_code: "DE", locale: "en" }
    }, as: :json
    assert_response :success
    assert_equal "Goldie", json_body.dig("data", "display_name")
    assert_equal "DE", @user.profile.reload.country_code
  end

  test "changing the password requires the current password" do
    patch "/api/v1/account/password", params: {
      current_password: "Wrong-Current",
      password: "New-Pass-777",
      password_confirmation: "New-Pass-777"
    }, as: :json
    assert_response :unprocessable_content
    assert_equal "invalid_password", json_body.dig("error", "code")
  end

  test "changing the password revokes all other sessions" do
    other = Auth::Login.call(email: @user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal 2, @user.sessions.active_now.count

    patch "/api/v1/account/password", params: {
      current_password: SupportHelpers::DEFAULT_PASSWORD,
      password: "New-Pass-777",
      password_confirmation: "New-Pass-777"
    }, as: :json
    assert_response :success

    assert_equal 1, @user.reload.sessions.active_now.count
    assert_not other.session.reload.active?
    assert @user.authenticate("New-Pass-777")
  end

  test "lists active sessions and revokes a target session" do
    Auth::Login.call(email: @user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    get "/api/v1/account/sessions"
    assert_response :success
    assert_equal 2, json_body["data"].size

    target_id = json_body["data"].first["id"]
    delete "/api/v1/account/sessions/#{target_id}"
    assert_response :no_content
    assert_equal 1, @user.sessions.active_now.count
  end

  test "activity endpoint returns only the user's own audit trail" do
    get "/api/v1/account/activity"
    assert_response :success
    assert json_body["data"].any? { |event| event["action"] == "user.signed_in" }
  end
end