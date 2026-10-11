# frozen_string_literal: true

module Games
  # Maps a game slug to its maths class.
  #
  # Adding a title means adding a class under Games::Slots and one entry here;
  # the API, admin area and frontend pick it up with no further wiring.
  module Registry
    CATALOG = {
      "dragon_fortune" => Games::Slots::DragonFortune,
      "buffalo_fortune" => Games::Slots::BuffaloFortune
    }.freeze

    module_function

    def math_for(slug)
      CATALOG.fetch(slug.to_s) do
        raise ArgumentError, "No maths registered for game '#{slug}'"
      end
    end

    def slugs
      CATALOG.keys
    end

    def registered?(slug)
      CATALOG.key?(slug.to_s)
    end
  end
end