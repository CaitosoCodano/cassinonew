require "test_helper"

class AuthLoginTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "signs in with valid credentials and creates a server-side session" do
    user = create_user
    result = Auth::Login.call(
      email: user.email,
      password: SupportHelpers::DEFAULT_PASSWORD,
      ip: "127.0.0.1",
      user_agent: "RSpec/Test"
    )

    assert result.success?
    assert_not_nil result.session
    assert_not_nil result.raw_token
    assert_equal user.id, result.user.id
    assert_equal 1, user.sessions.count
    assert_equal user.sessions.first.token_digest, Session.digest(result.raw_token)
  end

  test "rejects an invalid password" do
    user = create_user
    result = Auth::Login.call(email: user.email, password: "Wrong-Pass-123")
    assert_not result.success?
    assert_equal :invalid_credentials, result.error
    assert_equal 1, user.reload.failed_sign_in_attempts
  end

  test "locks the account after too many failures" do
    user = create_user
    5.times do
      Auth::Login.call(email: user.email, password: "Wrong-Pass-123")
    end

    assert_not_nil user.reload.locked_at

    locked = Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal :locked, locked.error
  end

  test "rejects suspended accounts" do
    user = create_user(status: :suspended)
    result = Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal :suspended, result.error
  end

  test "rejects accounts under an active self-exclusion" do
    user = create_user
    user.account_restrictions.create!(kind: :self_exclusion, starts_at: Time.current)
    result = Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal :restricted, result.error
  end

  test "does not reveal whether an email exists (uniform errors)" do
    anonymous = Auth::Login.call(email: "ghost@example.com", password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal :invalid_credentials, anonymous.error
  end
end