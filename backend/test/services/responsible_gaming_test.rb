require "test_helper"

class ResponsibleGamingTest < ActiveSupport::TestCase
  setup { ensure_roles! }

  test "players can set a new limit" do
    user = create_user
    limit = ResponsibleGaming::SetLimit.call(user: user, kind: :deposit, period: :daily, amount_minor: 1000)

    assert limit.persisted?
    assert_equal 1000, limit.amount_minor
    assert limit.active?
  end

  test "players cannot loosen an existing limit" do
    user = create_user
    ResponsibleGaming::SetLimit.call(user: user, kind: :deposit, period: :daily, amount_minor: 1000)

    assert_raises(ResponsibleGaming::LimitError) do
      ResponsibleGaming::SetLimit.call(user: user, kind: :deposit, period: :daily, amount_minor: 2000)
    end
  end

  test "players can tighten an existing limit" do
    user = create_user
    ResponsibleGaming::SetLimit.call(user: user, kind: :deposit, period: :daily, amount_minor: 1000)
    limit = ResponsibleGaming::SetLimit.call(user: user, kind: :deposit, period: :daily, amount_minor: 500)

    assert_equal 500, limit.amount_minor
  end

  test "self-exclusion revokes all sessions and blocks subsequent logins" do
    user = create_user
    Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal 1, user.sessions.count

    restriction = ResponsibleGaming::SelfExclude.call(user: user, duration_days: 30, reason: "test")
    assert restriction.active?
    assert_equal 0, user.sessions.active_now.count

    login = Auth::Login.call(email: user.email, password: SupportHelpers::DEFAULT_PASSWORD)
    assert_equal :restricted, login.error
  end
end