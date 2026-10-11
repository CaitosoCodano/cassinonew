module Games
  # Registry of available game-integration adapters.
  #
  # Adapters must be registered EXPLICITLY at boot (see
  # config/initializers/game_providers.rb). The platform never auto-requires,
  # evals or constantises strings coming from the database -- doing so would
  # allow arbitrary code execution from a compromised admin account or a
  # malicious provider record.
  module ProviderRegistry
    class UnknownAdapterError < StandardError; end

    @adapters = {}

    class << self
      # @param adapter_class [Class] a Games::Adapters::BaseAdapter subclass
      def register(adapter_class)
        unless adapter_class.is_a?(Class) && adapter_class <= Games::Adapters::BaseAdapter
          raise ArgumentError, "#{adapter_class.inspect} must subclass Games::Adapters::BaseAdapter"
        end

        @adapters[adapter_class.name] = adapter_class
      end

      def registered
        @adapters.dup
      end

      def registered?(name)
        @adapters.key?(name.to_s)
      end

      def resolve!(name)
        adapter = @adapters[name.to_s]
        raise UnknownAdapterError, "No integration adapter registered for #{name.inspect}" if adapter.nil?

        adapter
      end

      # Reset helper used by tests.
      def clear!
        @adapters = {}
      end
    end
  end
end
