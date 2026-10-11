require "test_helper"

class GamesSessionLauncherTest < ActiveSupport::TestCase
  setup do
    ensure_roles!
    Games::ProviderRegistry.register(TestAdapters::FakeAdapter)
  end

  teardown do
    Games::ProviderRegistry.clear!
  end

  test "returns provider_not_configured when no adapter is registered" do
    user = create_user
    provider = create_provider(slug: "unconfigured", adapter_class: nil, integration_version: nil)
    game = create_game(provider: provider, slug: "mystery")

    result = Games::SessionLauncher.call(user: user, game: game)
    assert_not result.success?
    assert_equal :provider_not_configured, result.error
    assert_equal 0, GameSession.count
  end

  test "refuses restricted accounts" do
    user = create_user
    provider = create_provider
    game = create_game(provider: provider)
    user.account_restrictions.create!(kind: :self_exclusion, starts_at: Time.current)

    result = Games::SessionLauncher.call(user: user, game: game)
    assert_equal :account_restricted, result.error
  end

  test "launches a session through the adapter" do
    user = create_user
    provider = create_provider
    game = create_game(provider: provider)

    result = Games::SessionLauncher.call(user: user, game: game)

    assert result.success?
    assert_match %r{https://fake\.example/play/}, result.launch_url
    session = result.game_session
    assert session.active?
    assert_not_nil session.provider_session_reference
    assert_not_nil session.started_at
  end

  test "hidden games cannot be launched" do
    user = create_user
    provider = create_provider
    game = create_game(provider: provider, status: :hidden)

    result = Games::SessionLauncher.call(user: user, game: game)
    assert_equal :game_unavailable, result.error
  end
end