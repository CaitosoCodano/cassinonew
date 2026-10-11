require "test_helper"

# The maths layer is the part of a casino platform an auditor would read, so it
# is tested for shape, determinism and sanity rather than for "looks nice".
class Games::Slots::MathsTest < ActiveSupport::TestCase
  include SupportHelpers

  setup do
    @provider = create_provider(slug: "internal", name: "Luminara Originals", adapter_class: nil)
  end

  # --- registry -------------------------------------------------------------

  test "registry exposes both shipped titles" do
    assert_equal %w[buffalo_fortune dragon_fortune], Games::Registry.slugs.sort
    assert Games::Registry.registered?("dragon_fortune")
    assert_not Games::Registry.registered?("nope")
  end

  test "registry raises for an unknown slug instead of silently playing nothing" do
    assert_raises(ArgumentError) { Games::Registry.math_for("ghost_game") }
  end

  # --- reel strips ----------------------------------------------------------

  test "reel strips are built with positive integer weights" do
    Games::Registry.slugs.each do |slug|
      math = Games::Registry.math_for(slug)
      strips = Games::ReelStripFactory.build(math::STRIPS)

      assert_equal math::REELS, strips.size, "#{slug} should have 5 reels"
      strips.each do |strip|
        assert_operator strip.total_weight, :>, 0
        strip.entries.each do |symbol, weight|
          assert_operator weight, :>, 0
          assert_includes math::SYMBOLS, symbol
        end
      end
    end
  end

  test "strip picking is deterministic for a given seed" do
    strip = Games::Slots::BaseSlot::ReelStrip.new([[:COMMON, 1], [:RARE, 1]])
    a = Array.new(20) { strip.pick(Games::Rng.from_seed("fixed-seed")) }
    b = Array.new(20) { strip.pick(Games::Rng.from_seed("fixed-seed")) }
    assert_equal a, b
  end

  test "strip picking honours relative weights" do
    strip = Games::Slots::BaseSlot::ReelStrip.new([[:COMMON, 99], [:RARE, 1]])
    picks = Array.new(2000) { strip.pick(Games::Rng.from_seed(SecureRandom.hex(8))) }
    ratio = picks.count(:COMMON).to_f / picks.size
    assert_operator ratio, :>, 0.9, "a 99/100 weight should dominate"
  end

  # --- grid + evaluation ----------------------------------------------------

  test "generated grids always have 5 reels of 3 rows of known symbols" do
    Games::Registry.slugs.each do |slug|
      math = Games::Registry.math_for(slug)
      strips = Games::ReelStripFactory.build(math::STRIPS)
      grid = Games::Slots::BaseSlot.generate_grid(Games::Rng.from_seed("s"), strips: strips)

      assert_equal 5, grid.size
      grid.each { |column| assert_equal 3, column.size }
      grid.flatten.each { |s| assert_includes math::SYMBOLS, s }
    end
  end

  test "a five of a kind on a line pays the top paytable value" do
    math = Games::Registry.math_for("dragon_fortune")
    # grid[col][row]; the middle line runs col 0..4 at row 1.
    grid = [["Q", "A", "Q"], ["Q", "A", "Q"], ["Q", "A", "Q"], ["Q", "A", "Q"], ["Q", "A", "Q"]]
    line = [[1, 0], [1, 1], [1, 2], [1, 3], [1, 4]]

    result = Games::Slots::BaseSlot.evaluate_lines(
      grid, paylines: [line], paytable: math::PAYTABLE, wild: math::WILD
    )

    assert_equal 1, result[:lines].size
    assert_equal "a", result[:lines].first["symbol"]
    assert_equal 5, result[:lines].first["count"]
    assert_equal math::PAYTABLE["a"][2], result[:lines].first["value"]
  end

  test "a broken line of two pays nothing" do
    math = Games::Registry.math_for("dragon_fortune")
    # A A then a K breaks the run before three.
    grid = [["A", "A", "Q"], ["A", "A", "Q"], ["K", "K", "Q"], ["J", "J", "Q"], ["10", "10", "Q"]]
    line = [[1, 0], [1, 1], [1, 2], [1, 3], [1, 4]]

    result = Games::Slots::BaseSlot.evaluate_lines(
      grid, paylines: [line], paytable: math::PAYTABLE, wild: math::WILD
    )
    assert_empty result[:lines]
  end

  test "a wild substitutes for the base symbol" do
    math = Games::Registry.math_for("dragon_fortune")
    # K WILD K K K on the middle line: the wild stands in for the second K.
    grid = [["K", "K", "Q"], ["WILD", "K", "Q"], ["K", "K", "Q"], ["K", "K", "Q"], ["K", "K", "Q"]]
    line = [[1, 0], [1, 1], [1, 2], [1, 3], [1, 4]]

    result = Games::Slots::BaseSlot.evaluate_lines(
      grid, paylines: [line], paytable: math::PAYTABLE, wild: math::WILD
    )
    assert_equal 1, result[:lines].size
    assert_equal "k", result[:lines].first["symbol"]
    assert_equal 5, result[:lines].first["count"]
  end

  test "a line of nothing but wilds has no base symbol to pay" do
    math = Games::Registry.math_for("dragon_fortune")
    grid = [["WILD", "WILD", "Q"]] * 5
    line = [[1, 0], [1, 1], [1, 2], [1, 3], [1, 4]]

    result = Games::Slots::BaseSlot.evaluate_lines(
      grid, paylines: [line], paytable: math::PAYTABLE, wild: math::WILD
    )
    assert_empty result[:lines]
  end

  test "the paytable has no entry for the wild itself" do
    Games::Registry.slugs.each do |slug|
      math = Games::Registry.math_for(slug)
      assert_nil math::PAYTABLE["w"], "#{slug} must not pay a bare wild"
      assert_nil math::PAYTABLE["wild"], "#{slug} must not pay a bare wild"
    end
  end

  test "every declared payline references a real cell" do
    Games::Registry.slugs.each do |slug|
      math = Games::Registry.math_for(slug)
      assert_equal 20, math::PAYLINES.size, "#{slug} should declare 20 paylines"

      math::PAYLINES.each do |line|
        assert_equal 5, line.size
        line.each do |row, col|
          assert_includes 0..2, row, "#{slug} row out of range"
          assert_includes 0..4, col, "#{slug} column out of range"
        end
      end
    end
  end

  test "scatters are counted anywhere on the grid" do
    math = Games::Registry.math_for("dragon_fortune")
    grid = [["SCATTER"], ["10"], ["SCATTER"], ["K"], ["SCATTER"]]

    result = Games::Slots::BaseSlot.evaluate_scatters(grid, scatter: math::SCATTER)
    assert_equal 3, result[:count]
    assert_equal 3, result[:positions].size
  end

  # --- round engine ---------------------------------------------------------

  test "the round engine returns a complete, self-describing outcome" do
    outcome = engine_round("dragon_fortune", 1000)

    assert_equal 5, outcome.grid.size
    assert_kind_of Array, outcome.line_wins
    assert_kind_of Hash, outcome.scatter
    assert_operator outcome.total_units, :>=, 0
    assert_kind_of Array, outcome.events
  end

  test "the same seed replays the same round bit for bit" do
    math = Games::Registry.math_for("dragon_fortune")

    a = Games::RoundEngine.new(game_class: math, bet_minor: 1000,
                               rng: Games::Rng.from_seed("replay-check"), scale: 1.0).call
    b = Games::RoundEngine.new(game_class: math, bet_minor: 1000,
                               rng: Games::Rng.from_seed("replay-check"), scale: 1.0).call

    assert_equal a.to_h, b.to_h, "a stored seed must replay identically"
  end

  test "a bought bonus always awards free spins" do
    outcome = engine_round("dragon_fortune", 100, buy_bonus: true)
    assert_predicate outcome.free_spins, :any?
    assert_includes outcome.events, "buy_bonus"
  end

  test "free spins resolve fully server-side with a rising multiplier" do
    math = Games::Registry.math_for("buffalo_fortune")
    outcome = engine_round("buffalo_fortune", 100, buy_bonus: true)
    spins = outcome.free_spins

    assert_operator spins.size, :>, 1

    multipliers = spins.map { |s| s["multiplier"] }
    assert_equal multipliers.sort, multipliers, "the ladder must not go backwards"
    assert_operator multipliers.first, :>=, 1
    assert_operator multipliers.max, :<=, math::BONUS_MULTIPLIER_CAP
    assert_operator multipliers.max, :>, 1, "the ladder must actually climb"

    # It climbs one step at a time and then holds at the cap.
    multipliers.each_cons(2) do |a, b|
      assert_operator b, :>=, a
      assert_operator b - a, :<=, math::BONUS_MULTIPLIER_STEP
    end
  end

  test "free spin totals accumulate monotonically" do
    outcome = engine_round("dragon_fortune", 100, buy_bonus: true)
    totals = outcome.free_spins.map { |s| s["total_after"] }

    assert_equal totals.sort, totals
    assert_in_delta outcome.free_spins.sum { |s| s["win_units"] }, totals.last, 0.01
  end

  test "payout scale multiplies the win proportionally" do
    math = Games::Registry.math_for("dragon_fortune")

    low = Games::RoundEngine.new(game_class: math, bet_minor: 100_000,
                                 rng: Games::Rng.from_seed("scale-check"), scale: 1.0).call
    high = Games::RoundEngine.new(game_class: math, bet_minor: 100_000,
                                  rng: Games::Rng.from_seed("scale-check"), scale: 2.0).call

    assert_in_delta low.total_units * 2.0, high.total_units, 0.01
  end

  test "no spin can ever return an implausible multiple of the stake" do
    # Guards against a paytable typo paying out the entire float budget.
    Games::Registry.slugs.each do |slug|
      100.times do
        outcome = engine_round(slug, 10_000)
        assert_operator outcome.total_units, :<=, 10_000 * 1_000,
                        "#{slug} produced an implausible win"
      end
    end
  end

  test "the buffalo super symbol multiplies the spin" do
    math = Games::Registry.math_for("buffalo_fortune")
    grid = [["BUFF"], ["BUFF"], ["BUFF"], ["BUFF"], ["10"]]

    result = Games::Slots::BaseSlot.evaluate_scatters(grid, scatter: math::SCATTER)
    assert_equal 0, result[:count]

    count = grid.flatten.count(math::BUFFALO)
    assert_equal 4, count
    assert_operator math::BUFFALO_TIERS[count], :>, 1
  end

  private

  def engine_round(slug, bet, buy_bonus: false)
    Games::RoundEngine.new(
      game_class: Games::Registry.math_for(slug),
      bet_minor: bet,
      rng: Games::Rng.from_seed(SecureRandom.hex(16)),
      scale: 1.0,
      buy_bonus: buy_bonus
    ).call
  end
end