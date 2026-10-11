require "test_helper"

# These cover the journey a real player takes, and specifically the two bugs
# that made the product feel broken:
#
#   1. registering left the player logged out, so the balance and the games
#      were unreachable until they typed the password again;
#   2. a balance shown after login must be the same balance the ledger holds,
#      on a brand new connection as well as in the one that spent it.
class PlayerJourneyTest < ActionDispatch::IntegrationTest
  include SupportHelpers

  setup do
    @password = "Camelo-Corre-Pora-Mar-9"
    # Registration resolves the player role from the database, so the roles have
    # to exist before the request rather than being created by a helper.
    ensure_roles!
  end

  # --- registration --------------------------------------------------------

  test "registering signs the player in immediately" do
    email = "novo-#{SecureRandom.hex(4)}@example.com"

    post "/api/v1/auth/register", params: {
      email: email, password: @password, password_confirmation: @password
    }, as: :json
    assert_response :created

    # The session must already work; this is what was broken before.
    get "/api/v1/auth/session"
    assert_response :success
    assert_equal email, json_body.dig("data", "email")
  end

  test "a newly registered player can read their wallet straight away" do
    email = "novo-#{SecureRandom.hex(4)}@example.com"

    # The suite runs with the welcome bonus off so exact balances can be
    # asserted elsewhere; this test opts back in to cover the real behaviour.
    original = ENV["WELCOME_BONUS_MINOR"]
    ENV["WELCOME_BONUS_MINOR"] = "100_000"

    post "/api/v1/auth/register", params: {
      email: email, password: @password, password_confirmation: @password
    }, as: :json
    assert_response :created

    get "/api/v1/wallet"
    assert_response :success

    wallet = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }
    assert_not_nil wallet, "a new account must have a play-money wallet"
    assert_operator wallet["balance_minor"], :>, 0, "welcome credit must be available to play"
  ensure
    ENV["WELCOME_BONUS_MINOR"] = original
  end

  test "registration records the session for auditing" do
    email = "novo-#{SecureRandom.hex(4)}@example.com"

    post "/api/v1/auth/register", params: {
      email: email, password: @password, password_confirmation: @password
    }, as: :json
    assert_response :created

    session = json_body.dig("data", "id")
    user = User.find_by(email: email)
    assert_equal 1, user.sessions.count

    event = AuditEvent.where(action: "session.created").order(:id).last
    assert_equal "registration", event.metadata["reason"]
    assert session.positive?
  end

  test "a rejected registration does not create a session" do
    post "/api/v1/auth/register", params: {
      email: "curto@example.com", password: "abc", password_confirmation: "abc"
    }, as: :json

    assert_response :unprocessable_content
    assert_nil json_body.dig("data", "id")

    get "/api/v1/auth/session"
    assert_response :no_content
  end

  # --- logging in ----------------------------------------------------------

  test "logging in returns the player and their balance" do
    user = create_user(password: @password)
    login_as(user, password: @password)

    get "/api/v1/wallet"
    wallet = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }
    assert_equal user.virtual_wallet.balance_minor, wallet["balance_minor"]
  end

  test "the balance a player sees is the balance the ledger holds" do
    user = create_user(password: @password)
    login_as(user, password: @password)

    get "/api/v1/wallet"
    reported = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }["balance_minor"]
    on_disk = user.virtual_wallet.reload.balance_minor
    assert_equal on_disk, reported
  end

  # --- balance survives a fresh connection ---------------------------------

  test "a balance spent in one session is still spent in the next" do
    user = create_user(password: @password)
    wallet = user.virtual_wallet
    wallet.update!(balance_minor: 50_000)
    opening = wallet.balance_minor
    game = create_game(provider: create_provider(slug: "internal", adapter_class: nil),
                       slug: "dragon_fortune", name: "Dragon Fortune",
                       min_bet_minor: 100, max_bet_minor: 1_000_000)

    login_as(user, password: @password)
    post "/api/v1/games/#{game.id}/rounds", params: { bet_minor: 500 }, as: :json
    assert_response :created
    spent = json_body.dig("data", "balance_minor")

    # A completely new client, as if the browser had been closed and reopened.
    reset!
    login_as(user, password: @password)

    get "/api/v1/wallet"
    reopened = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }["balance_minor"]

    assert_equal spent, reopened, "the balance must survive losing the session"
    assert_operator spent, :<, opening
    assert_equal wallet.reload.balance_minor, reopened
  end

  test "logging out ends the session and the balance is no longer readable" do
    user = create_user(password: @password)
    login_as(user, password: @password)

    delete "/api/v1/auth/logout"
    assert_response :no_content

    get "/api/v1/wallet"
    assert_response :unauthorized
  end

  test "logging out then back in shows the same balance" do
    user = create_user(password: @password)
    login_as(user, password: @password)

    get "/api/v1/wallet"
    before = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }["balance_minor"]

    delete "/api/v1/auth/logout"
    assert_response :no_content

    login_as(user, password: @password)
    get "/api/v1/wallet"
    after = json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }["balance_minor"]

    assert_equal before, after
  end

  # --- failed attempts -----------------------------------------------------

  test "the wrong password is refused and issues no session" do
    user = create_user(password: @password)
    reset!

    post "/api/v1/auth/login",
         params: { email: user.email, password: "Senha-Completa-Mentira-1" }, as: :json

    # 401 is the honest answer: the request was unauthenticated, not malformed.
    assert_response :unauthorized
    assert_equal "invalid_credentials", json_body.dig("error", "code")

    get "/api/v1/auth/session"
    assert_response :no_content
  end

  test "an unknown email is refused with the same message as a wrong password" do
    create_user(password: @password)
    reset!

    post "/api/v1/auth/login",
         params: { email: "ningum@exemplo.com", password: @password }, as: :json
    unknown_status = response.status
    unknown_message = json_body.dig("error", "message")

    post "/api/v1/auth/login",
         params: { email: "ningum@exemplo.com", password: "Outra-Senha-Muito-9" }, as: :json

    # Identical responses: the API must not reveal whether an account exists.
    assert_equal unknown_status, response.status
    assert_equal unknown_message, json_body.dig("error", "message")
  end

  test "a mismatched confirmation is rejected" do
    post "/api/v1/auth/register", params: {
      email: "descasado@example.com", password: @password, password_confirmation: "Outra-Senha-9"
    }, as: :json

    assert_response :unprocessable_content
    assert_nil User.find_by(email: "descasado@example.com")
  end

  test "a duplicate email is rejected without disturbing the original account" do
    original = create_user(password: @password)
    opening = original.virtual_wallet.balance_minor
    reset!

    post "/api/v1/auth/register", params: {
      email: original.email, password: "Outra-Senha-Muito-9", password_confirmation: "Outra-Senha-Muito-9"
    }, as: :json
    assert_response :unprocessable_content

    login_as(original, password: @password)
    get "/api/v1/wallet"
    assert_equal opening,
                 json_body.dig("data", "wallets").find { |w| w["kind"] == "virtual" }["balance_minor"]
  end
end