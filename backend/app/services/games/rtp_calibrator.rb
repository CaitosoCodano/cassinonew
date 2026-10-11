# frozen_string_literal: true

module Games
  # Measures the real return-to-player of a game by simulation.
  #
  # The operator sets a *target* RTP. To hit it we need to know what the
  # unmodified paytable actually returns, then scale every payout by the ratio.
  # Measuring rather than guessing is the whole point: the admin screen shows a
  # simulated figure with a confidence interval, and the raw RTP for the current
  # paytable is reported alongside it.
  module RtpCalibrator
    SIM_SPINS = Integer(ENV.fetch("GAMES_RTP_SIM_SPINS", 40_000))
    SIM_SEED = "rtp-calibration-v1"

    Result = Struct.new(:slug, :spins, :staked_minor, :returned_minor, :rtp_percent,
                        :scale, :stdev_percent, :margin_error_percent, keyword_init: true) do
      def to_h
        {
          "slug" => slug,
          "spins" => spins,
          "staked_minor" => staked_minor,
          "returned_minor" => returned_minor,
          "rtp_percent" => rtp_percent.round(4),
          "scale" => scale.round(6),
          "stdev_percent" => stdev_percent.round(4),
          "margin_error_percent" => margin_error_percent.round(4)
        }
      end
    end

    module_function

    # Measures the game's native (unscaled) RTP at a reference bet, including
    # the free-spin continuation (that is where most of the return lives).
    def measure_native_rtp(slug, spins: SIM_SPINS, bet_minor: 100)
      math = Registry.math_for(slug)
      rng = Games::Rng.from_seed(SIM_SEED)
      strips = ReelStripFactory.build(math::STRIPS)

      returned = 0.0
      spins.times do
        returned += native_win_units(math: math, grid: generate(math, rng, strips), bet_minor: bet_minor)
      end

      returned / (spins * bet_minor.to_f) * 100.0
    end

    def generate(math, rng, strips)
      Games::Slots::BaseSlot.generate_grid(rng, strips: strips)
    end

    # Win for a single grid, without the free-spin continuation.
    def single_spin_win_units(math:, grid:, bet_minor:)
      line_bet = bet_minor.to_f / math::PAYLINES.size

      lines = Games::Slots::BaseSlot.evaluate_lines(
        grid, paylines: math::PAYLINES, paytable: math::PAYTABLE, wild: math::WILD
      )
      scatter = Games::Slots::BaseSlot.evaluate_scatters(grid, scatter: math::SCATTER)

      units = lines[:total_units] * line_bet
      units += math::SCATTER_PAYS[scatter[:count]].to_f * line_bet

      if defined?(math::BUFFALO_TIERS)
        count = grid.flatten.count(math::BUFFALO)
        if count >= 3
          tier = math::BUFFALO_TIERS[count] || math::BUFFALO_TIERS.values.max
          units += tier * line_bet
        end
      end

      # Include the game's own paytable normalisation so the measurement
      # reports the native RTP an operator actually starts from (~96%).
      units * math::PAYTABLE_SCALE
    end

    # Win for a grid including its triggered free-spin sequence.
    def native_win_units(math:, grid:, bet_minor:, rng: nil, strips: nil)
      rng ||= Games::Rng.from_seed(SIM_SEED)
      strips ||= ReelStripFactory.build(math::STRIPS)

      units = single_spin_win_units(math: math, grid: grid, bet_minor: bet_minor)

      scatter = Games::Slots::BaseSlot.evaluate_scatters(grid, scatter: math::SCATTER)
      count = scatter[:count]
      return units if count < 3

      math::SCATTER_FREE_SPINS[count].to_i.times do |index|
        step = ((index + 1) * math::BONUS_MULTIPLIER_STEP).clamp(1, math::BONUS_MULTIPLIER_CAP)
        free_grid = generate(math, rng, strips)
        units += single_spin_win_units(math: math, grid: free_grid, bet_minor: bet_minor) * step
      end

      units
    end

    # Cache of measured native RTP so the admin screen is instant and the
    # (expensive) simulation runs once per process.
    @cache = {}
    @mutex = Mutex.new

    def native_rtp(slug)
      @mutex.synchronize do
        @cache[slug.to_s] ||= measure_native_rtp(slug)
      end
    end

    # Payout multiplier that moves the native RTP onto the operator's target.
    #
    # Buy-bonus rounds are excluded from the calibration on purpose: they are
    # priced separately at a fixed cost and deliberately return less, which is
    # how operators fund the feature.
    def scale_for(slug, target_rtp_percent)
      native = native_rtp(slug)
      return 1.0 if native <= 0.0

      target = target_rtp_percent.to_f
      ratio = target / native
      # A zero or negative scale would mean no game at all; keep a floor so the
      # reels still occasionally produce a return and the demo stays playable.
      [ratio, 0.0001].max
    end

    # Full report for the admin screen.
    def report(slug, target_rtp_percent: nil, spins: SIM_SPINS, bet_minor: 100)
      target = target_rtp_percent || Games::Config["user_rtp_percent"]
      scale = scale_for(slug, target)

      rng = Games::Rng.from_seed(SIM_SEED)
      math = Registry.math_for(slug)
      strips = ReelStripFactory.build(math::STRIPS)

      returns = Array.new(spins) do
        grid = Games::Slots::BaseSlot.generate_grid(rng, strips: strips)
        native_win_units(math: math, grid: grid, bet_minor: bet_minor, rng: rng, strips: strips) * scale
      end

      mean = returns.sum / spins.to_f
      variance = returns.sum { |r| (r - mean)**2 } / [spins - 1, 1].max
      stdev = Math.sqrt(variance)
      # 95% confidence half-width on the mean.
      margin = 1.96 * stdev / Math.sqrt(spins)

      Result.new(
        slug: slug.to_s,
        spins: spins,
        staked_minor: spins * bet_minor,
        returned_minor: (returns.sum).round(2),
        rtp_percent: (mean / bet_minor) * 100.0,
        scale: scale,
        stdev_percent: (stdev / bet_minor) * 100.0,
        margin_error_percent: (margin / bet_minor) * 100.0
      )
    end
  end
end