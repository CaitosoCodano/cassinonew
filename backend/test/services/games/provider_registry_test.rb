require "test_helper"

class GamesProviderRegistryTest < ActiveSupport::TestCase
  setup do
    Games::ProviderRegistry.clear!
  end

  teardown do
    Games::ProviderRegistry.clear!
  end

  test "registers and resolves an adapter" do
    Games::ProviderRegistry.register(TestAdapters::FakeAdapter)
    assert Games::ProviderRegistry.registered?(TestAdapters::FakeAdapter.name)
    assert_equal TestAdapters::FakeAdapter, Games::ProviderRegistry.resolve!(TestAdapters::FakeAdapter.name)
  end

  test "unregistered adapters are rejected with a dedicated error" do
    assert_raises(Games::ProviderRegistry::UnknownAdapterError) do
      Games::ProviderRegistry.resolve!("Some::Missing::Adapter")
    end
  end

  test "refuses to register objects that are not BaseAdapter subclasses" do
    assert_raises(ArgumentError) do
      Games::ProviderRegistry.register(String)
    end
  end

  test "resolving by constant name never evaluates arbitrary strings" do
    assert_raises(Games::ProviderRegistry::UnknownAdapterError) do
      Games::ProviderRegistry.resolve!("Object")
    end
  end
end