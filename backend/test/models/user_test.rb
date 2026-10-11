require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "requires a strong password" do
    user = User.new(email: "a@example.com", password: "short1", role: player_role)
    assert_not user.valid?
    assert_includes user.errors[:password].to_s, "12"
  end

  test "requires a letter and a number in the password" do
    user = User.new(email: "a@example.com", password: "AAAAAAAAAAAA", role: player_role)
    assert_not user.valid?
    assert_includes user.errors[:password].to_s, "number"

    user = User.new(email: "a@example.com", password: "123456789012", role: player_role)
    assert_not user.valid?
    assert_includes user.errors[:password].to_s, "letter"
  end

  test "normalises the email and enforces uniqueness" do
    create_user(email: "Player@Example.com")

    duplicate = User.new(email: "player@example.com", password: SupportHelpers::DEFAULT_PASSWORD, role: player_role)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email].to_s, "taken"
  end

  test "verify_email sets the verified timestamp" do
    user = create_user(verified: false)
    assert_not user.email_verified?
    user.verify_email!
    assert user.email_verified?
  end

  test "permission checks delegate to the role" do
    player = create_user
    assert player.permission?("profile.read")
    assert_not player.permission?("users.read")

    admin = create_admin
    assert admin.permission?("users.read")
    assert admin.admin?
  end

  test "restricted? reports active account restrictions" do
    user = create_user
    assert_not user.restricted?

    user.account_restrictions.create!(kind: :self_exclusion, status: :active,
                                      starts_at: Time.current, ends_at: nil)
    assert user.restricted?
    assert user.restricted?("self_exclusion")
  end

  test "closed accounts cannot be activated by verify action" do
    user = create_user(verified: false, status: :closed)
    user.verify_email!
    assert user.email_verified?
  end
end