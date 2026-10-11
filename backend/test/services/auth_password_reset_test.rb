require "test_helper"

class AuthPasswordResetTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "requesting a reset for an unknown email returns success silently" do
    assert_difference -> { PasswordResetToken.count }, 0 do
      success = Auth::PasswordReset::Request.call(email: "nobody@example.com")
      assert success
    end
  end

  test "requesting a reset issues a usable token for a known account" do
    user = create_user
    assert_difference -> { PasswordResetToken.count }, 1 do
      Auth::PasswordReset::Request.call(email: user.email)
    end

    token = user.password_reset_tokens.last
    assert token.usable?
    assert token.expires_at.future?
  end

  test "performing a reset changes the password, consumes the token and revokes sessions" do
    user = create_user
    Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal 1, user.sessions.count

    raw = PasswordResetToken.issue!(user: user)
    result = Auth::PasswordReset::Perform.call(
      token: raw,
      password: "New-Password-99",
      password_confirmation: "New-Password-99"
    )

    assert result.success?
    assert user.reload.authenticate("New-Password-99")
    assert_not user.authenticate(SupportHelpers::DEFAULT_PASSWORD)
    assert_not_nil result.user.password_reset_tokens.last.used_at
    assert_equal 0, user.sessions.active_now.count
  end

  test "a consumed token cannot be used twice" do
    user = create_user
    raw = PasswordResetToken.issue!(user: user)

    Auth::PasswordReset::Perform.call(token: raw, password: "New-Password-99",
                                      password_confirmation: "New-Password-99")
    second = Auth::PasswordReset::Perform.call(token: raw, password: "Another-Password-9",
                                               password_confirmation: "Another-Password-9")

    assert_not second.success?
    assert_not user.reload.authenticate("Another-Password-9")
  end
end