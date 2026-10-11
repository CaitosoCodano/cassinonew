require "test_helper"

# The suite runs with allow_forgery_protection off, so the CSRF flow the client
# depends on had no coverage at all: every other test posts without an
# X-CSRF-Token and passes. This file turns protection on for its own cases.
#
# It exists because a deployment failed at exactly this point: the browser got
# a 422 from POST /auth/register. Either the token was never bound to a session
# the server would accept, or it was. These tests decide which.
class CsrfFlowTest < ActionDispatch::IntegrationTest
  setup do
    @original = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
    ensure_roles!
  end

  teardown do
    ApplicationController.allow_forgery_protection = @original
  end

  test "the csrf endpoint hands back a token bound to a session" do
    get "/api/v1/auth/csrf"

    assert_response :success
    token = json_body.dig("data", "token")
    assert token.present?, "the client cannot send a state-changing request without a token"

    # The token is only meaningful if something survives to the next request.
    # form_authenticity_token writes into the session, and if the cookie never
    # leaves the server the comparison on the POST has nothing to compare to.
    session_cookie = cookies.to_hash.values.find { |v| v.is_a?(String) }
    assert session_cookie.present?,
           "no cookie was set, so the token cannot be validated on the following request"
  end

  test "registering with the issued token succeeds" do
    token = fetch_csrf_token

    post "/api/v1/auth/register",
         params: {
           email: "csrf-flow@example.com",
           password: "Senha-De-Teste-123",
           password_confirmation: "Senha-De-Teste-123"
         }.to_json,
         headers: json_headers(token)

    assert_response :created
    assert_equal "csrf-flow@example.com", json_body.dig("data", "email")
  end

  test "registering without the token is rejected" do
    post "/api/v1/auth/register",
         params: { email: "sem-token@example.com", password: "Senha-De-Teste-123",
                   password_confirmation: "Senha-De-Teste-123" }.to_json,
         headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_equal "invalid_csrf_token", json_body.dig("error", "code")
  end

  test "a token from a different session is rejected" do
    token = fetch_csrf_token

    # A second integration session has its own cookie jar, so it presents the
    # token without the cookie that binds it. That is what a browser with
    # cookies blocked, or a client that lost its jar between the two calls,
    # looks like.
    stranger = open_session
    stranger.post "/api/v1/auth/register",
                  params: { email: "outro-token@example.com", password: "Senha-De-Teste-123",
                            password_confirmation: "Senha-De-Teste-123" }.to_json,
                  headers: json_headers(token)

    assert_equal 422, stranger.response.status
    assert_equal "invalid_csrf_token",
                 JSON.parse(stranger.response.body).dig("error", "code")
  end

  test "registering also establishes a session" do
    post "/api/v1/auth/register",
         params: { email: "com-sessao@example.com", password: "Senha-De-Teste-123",
                   password_confirmation: "Senha-De-Teste-123" }.to_json,
         headers: json_headers(fetch_csrf_token)
    assert_response :created

    # The account existing is not enough. Without a session the player lands on
    # a verified address they cannot act on, and re-registering the same address
    # then fails with 422, which is exactly the failure that sent someone back
    # to the deploy log.
    get "/api/v1/auth/session"
    assert_response :success
    assert_equal "com-sessao@example.com", json_body.dig("data", "email")
  end

  test "login and logout work through the same token" do
    user = create_user
    token = fetch_csrf_token

    post "/api/v1/auth/login",
         params: { email: user.email, password: SupportHelpers::DEFAULT_PASSWORD }.to_json,
         headers: json_headers(token)
    assert_response :created

    # The session rotates on login, so the client refetches a token. Doing it
    # here too keeps the test honest about the sequence.
    delete "/api/v1/auth/logout", headers: json_headers(fetch_csrf_token)
    assert_response :no_content

    get "/api/v1/auth/session"
    assert_response :no_content
  end

  private

  def fetch_csrf_token
    get "/api/v1/auth/csrf"
    assert_response :success
    json_body.dig("data", "token")
  end

  def json_headers(token)
    { "Content-Type" => "application/json", "Accept" => "application/json", "X-CSRF-Token" => token }
  end
end