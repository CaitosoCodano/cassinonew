require "test_helper"

class AuthRegisterTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "creates a pending user with profile, wallet and verification token" do
    result = Auth::Register.call(
      email: "new@example.com",
      password: SupportHelpers::DEFAULT_PASSWORD,
      locale: "en",
      ip: "127.0.0.1"
    )

    assert result.success?
    user = result.user
    assert user.pending?
    assert_not user.email_verified?
    assert user.profile.present?
    assert user.virtual_wallet.present?
    assert_equal 0, user.virtual_wallet.balance_minor
    assert_equal 1, user.email_verification_tokens.count
    assert_equal Role::PLAYER, user.role.name
  end

  test "rejects duplicate email addresses" do
    create_user(email: "taken@example.com")
    result = Auth::Register.call(email: "taken@example.com", password: SupportHelpers::DEFAULT_PASSWORD)
    assert_not result.success?
    assert_includes result.errors.to_s, "taken"
  end

  test "rejects weak passwords" do
    result = Auth::Register.call(email: "weak@example.com", password: "short")
    assert_not result.success?
  end
end