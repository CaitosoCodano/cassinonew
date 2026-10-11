require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  setup { ensure_roles! }

  test "protected resources require authentication" do
    get "/api/v1/account"
    assert_response :unauthorized
    assert_equal "unauthorized", json_body.dig("error", "code")
  end

  test "anonymous sessions receive a CSRF token" do
    get "/api/v1/auth/csrf"
    assert_response :success
    assert json_body.dig("data", "token").present?
  end

  test "the session endpoint reports logged-out and logged-in state" do
    get "/api/v1/auth/session"
    assert_response :no_content

    user = create_user
    login_as(user)

    get "/api/v1/auth/session"
    assert_response :success
    assert_equal user.email, json_body.dig("data", "email")
  end

  test "registration, verification, login and logout lifecycle" do
    email = "lifecycle@example.com"
    password = SupportHelpers::DEFAULT_PASSWORD

    post "/api/v1/auth/register", params: { email: email, password: password, locale: "en" }, as: :json
    assert_response :created
    assert_equal "pending", json_body.dig("data", "status")

    user = User.find_by_email(email)

    raw_token = EmailVerificationToken.issue!(user: user)
    post "/api/v1/auth/email/verify", params: { token: raw_token }, as: :json
    assert_response :success
    assert user.reload.active?

    post "/api/v1/auth/login", params: { email: email, password: password }, as: :json
    assert_response :created

    get "/api/v1/account"
    assert_response :success

    delete "/api/v1/auth/logout"
    assert_response :no_content

    get "/api/v1/account"
    assert_response :unauthorized
  end

  test "login rejects bad credentials" do
    user = create_user
    post "/api/v1/auth/login", params: { email: user.email, password: "Wrong-Pass-1" }, as: :json
    assert_response :unauthorized
    assert_equal "invalid_credentials", json_body.dig("error", "code")
  end

  test "password reset request never leaks account existence" do
    post "/api/v1/auth/password/forgot", params: { email: "ghost@example.com" }, as: :json
    assert_response :accepted
  end

  test "config endpoint exposes public posture without secrets" do
    get "/api/v1/config"
    assert_response :success
    data = json_body["data"]
    assert data["brand"]["name"].present?
    assert_equal false, data["real_money_enabled"]
    assert data["currencies"].any? { |c| c["type"] == "virtual" }
  end
end