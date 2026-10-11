# frozen_string_literal: true

module Games
  # Cryptographically seeded RNG used for every game outcome.
  #
  # The seed is stored with the round, which means any recorded result can be
  # replayed bit-for-bit during a dispute investigation.
  class Rng
    def self.generate_seed
      SecureRandom.hex(32)
    end

    def self.from_seed(seed)
      new(seed)
    end

    def initialize(seed)
      @seed = seed.to_s
      # Expand the hex seed into a 256-bit integer so Ruby's Mersenne Twister
      # is seeded with full entropy from the crypto RNG.
      digest = Digest::SHA512.digest(@seed)
      @random = Random.new(digest.unpack1("H*").to_i(16))
    end

    attr_reader :seed

    # Integer in [min, max] inclusive, unbiased via rejection sampling.
    def int(min, max)
      return min if max <= min

      range = max - min + 1
      loop do
        value = @random.rand(range)
        return min + value if value < range
      end
    end

    # Drop-in for Ruby's Random#rand so anything expecting the standard
    # interface (including the reel strips) works unchanged.
    #
    #   rand      -> Float in [0, 1)
    #   rand(max) -> Integer in [0, max]
    def rand(max = nil)
      return @random.rand if max.nil?
      return 0 if max <= 1

      int(0, max - 1)
    end

    # Float in [0, 1).
    def float
      @random.rand
    end

    # True with probability expressed as a percentage (0..100).
    def chance?(percent)
      float < (percent.to_f / 100.0)
    end
  end
end