# Game integration adapter registration.
#
# Every adapter that ships with this deployment must be listed here. The
# platform deliberately does NOT auto-discover adapters: only code that is
# present in the repository and explicitly registered can ever run.
#
# This deployment ships the contract (Games::Adapters::BaseAdapter) and the
# registry only -- no provider integrations are bundled. The games lobby is
# therefore empty until an operator registers a real adapter and imports its
# catalog (see docs/ADDING_A_GAME_ADAPTER.md).
#
# Example:
#
#   Rails.application.config.after_initialize do
#     Games::ProviderRegistry.register(Games::Adapters::ExampleProviderAdapter)
#   end
#
Rails.application.config.to_prepare do
  # Intentionally empty. Register real adapters here.
  Games::ProviderRegistry
end
