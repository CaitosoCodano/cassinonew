# frozen_string_literal: true

module Games
  # Resolves a complete round on the server.
  #
  # Everything the client will ever display is decided here, in one call:
  #   * the paying spin,
  #   * the entire free-spin sequence (every spin, every multiplier, every win),
  #   * the running total,
  #   * the final balance effect.
  #
  # Generating the full sequence up front is what makes "never truncate a round"
  # structurally true rather than a UI promise: the client cannot skip spins,
  # re-roll them, or stop early, because there is nothing left to request.
  class RoundEngine
    MAX_FREE_SPINS = 100

    Outcome = Struct.new(
      :grid, :line_wins, :scatter, :base_units, :buffalo_tiers, :buffalo_multiplier,
      :win_units, :free_spins, :total_units, :events, keyword_init: true
    ) do
      def to_h
        {
          "grid" => grid,
          "line_wins" => line_wins,
          "scatter" => scatter,
          "base_units" => base_units,
          "buffalo_tiers" => buffalo_tiers,
          "buffalo_multiplier" => buffalo_multiplier,
          "win_units" => win_units,
          "free_spins" => free_spins,
          "total_units" => total_units,
          "events" => events
        }
      end
    end

    def initialize(game_class:, bet_minor:, rng:, scale:, buy_bonus: false)
      @game = game_class
      @bet_minor = bet_minor
      @rng = rng
      # Two multipliers stack here: the game's own PAYTABLE_SCALE, which
      # normalises the authored paytable onto a standard ~96% native RTP, and
      # the operator scale, which moves that 96% onto the configured RTP.
      @scale = scale * game_class::PAYTABLE_SCALE
      @buy_bonus = buy_bonus
      @strips = ReelStripFactory.build(@game::STRIPS)
    end

    def call
      grid = generate_grid
      base = evaluate(grid)

      scatter = base[:scatter]
      free_spin_count = if @buy_bonus
                          @game::SCATTER_FREE_SPINS.values.max
                        else
                          @game::SCATTER_FREE_SPINS[scatter[:count]].to_i
                        end

      total_units = base[:win_units]
      free_spins = []

      if free_spin_count.positive?
        free_spins = resolve_free_spins(free_spin_count)
        total_units += free_spins.sum { |s| s["win_units"] }
      end

      events = []
      events << "scatter" if scatter[:count] >= 3
      events << "buy_bonus" if @buy_bonus
      events << "buffalo_stampede" if base[:buffalo_multiplier].to_i > 1
      events << "free_spins" if free_spins.any?

      Outcome.new(
        grid: grid,
        line_wins: base[:lines],
        scatter: scatter.slice(:count, :positions),
        base_units: base[:base_units],
        buffalo_tiers: base[:buffalo_tiers],
        buffalo_multiplier: base[:buffalo_multiplier],
        win_units: total_units,
        free_spins: free_spins,
        total_units: total_units,
        events: events.uniq
      )
    end

    private

    def generate_grid
      Games::Slots::BaseSlot.generate_grid(@rng, strips: @strips)
    end

    def evaluate(grid)
      lines = Games::Slots::BaseSlot.evaluate_lines(
        grid,
        paylines: @game::PAYLINES,
        paytable: @game::PAYTABLE,
        wild: @game::WILD
      )
      scatter = Games::Slots::BaseSlot.evaluate_scatters(grid, scatter: @game::SCATTER)

      # Line wins are quoted in "line bets" where there are 20 lines, so the
      # wager per line is bet / 20. The payout scale maps the game's native
      # maths onto the operator's configured return-to-player.
      line_bet_units = (@bet_minor.to_f / @game::PAYLINES.size) * @scale
      base_units = lines[:total_units] * line_bet_units

      scatter_units = @game::SCATTER_PAYS[scatter[:count]].to_f * line_bet_units
      buffalo = buffalo_component(grid, line_bet_units)

      {
        lines: lines[:lines],
        scatter: scatter,
        base_units: base_units.round(4),
        win_units: (base_units + scatter_units + buffalo[:units]).round(4),
        buffalo_tiers: buffalo[:tiers],
        buffalo_multiplier: buffalo[:multiplier]
      }
    end

    # Buffalo super-symbols pay anywhere and multiply the rest of the spin.
    def buffalo_component(grid, line_bet_units)
      return { units: 0.0, tiers: [], multiplier: 1 } unless defined?(@game::BUFFALO_TIERS)

      count = grid.flatten.count(@game::BUFFALO)
      return { units: 0.0, tiers: [], multiplier: 1 } if count < 3

      positions = []
      grid.each_with_index do |column, col|
        column.each_with_index { |symbol, row| positions << [col, row] if symbol == @game::BUFFALO }
      end

      tier = @game::BUFFALO_TIERS[count] || @game::BUFFALO_TIERS.values.max
      { units: (tier * line_bet_units).round(4), tiers: [count], multiplier: tier }
    end

    # Resolves every free spin up front. Each spin raises the ladder multiplier
    # by the configured step up to the cap, so the bonus ramps visibly.
    def resolve_free_spins(count)
      limit = [count, MAX_FREE_SPINS].min
      total = 0.0
      spins = []

      limit.times do |index|
        grid = generate_grid
        result = evaluate(grid)
        multiplier = ((index + 1) * @game::BONUS_MULTIPLIER_STEP)
                    .clamp(1, @game::BONUS_MULTIPLIER_CAP)
        win = result[:win_units] * multiplier
        total += win

        spins << {
          "index" => index,
          "grid" => grid,
          "line_wins" => result[:lines],
          "scatter" => result[:scatter].slice(:count, :positions),
          "base_units" => result[:base_units],
          "buffalo_multiplier" => result[:buffalo_multiplier],
          "multiplier" => multiplier,
          "win_units" => win.round(4),
          "total_after" => total.round(4)
        }
      end

      spins
    end
  end
end