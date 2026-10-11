# frozen_string_literal: true

module Games
  # Builds the real reel strips for a game class.
  #
  # The game classes declare strips as compact grouped arrays like
  #   %w[10 10 10 J J Q]   -> {"10" => 3, "J" => 2, "Q" => 1}
  # which keeps the source readable while producing explicit weights.
  module ReelStripFactory
    module_function

    def build(strips)
      strips.map do |groups|
        weights = Hash.new(0)
        groups.each do |group|
          group.each { |symbol| weights[symbol] += 1 }
        end
        Games::Slots::BaseSlot::ReelStrip.new(weights.to_a)
      end
    end
  end
end