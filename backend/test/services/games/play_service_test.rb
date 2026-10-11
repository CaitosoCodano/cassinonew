require "test_helper"

# Playing a round is the only path that moves a balance, so it is tested for
# money safety: ledger integrity, refund on refusal and replayability.
class Games::PlayServiceTest < ActiveSupport::TestCase
  include SupportHelpers

  setup do
    @user = create_user
    @game = create_game(provider: create_provider(slug: "internal", name: "Originals", adapter_class: nil),
                        slug: "dragon_fortune", name: "Dragon Fortune",
                        min_bet_minor: 100, max_bet_minor: 1_000_000)
    @wallet = @user.wallets.find_by!(kind: :virtual, currency: "VCR")
    @wallet.update!(balance_minor: 10_000_000, status: :active)
  end

  test "a spin debits the stake and records it in the append-only ledger" do
    before = @wallet.balance_minor

    result = Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call

    assert_equal 1000, result.bet_minor
    # The stake always leaves; a win may put some back, but never more than won.
    assert_operator @wallet.reload.balance_minor, :<=, before
    assert_equal before - 1000 + result.win_minor, @wallet.balance_minor

    bet = @wallet.transactions.order(:id).last(2).detect { |t| t.kind == "bet" }
    assert_not_nil bet
    assert_equal(-1000, bet.amount_minor)
    assert_equal before, bet.balance_before_minor
  end

  test "the ledger reconciles to the balance after many rounds" do
    opening = @wallet.balance_minor
    20.times { Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call }

    delta = @wallet.reload.balance_minor - opening
    assert_equal delta, @wallet.ledger_entries.sum(:amount_minor),
                 "the append-only ledger must explain the balance exactly"
  end

  test "ledger sequences stay unique and ordered per wallet" do
    5.times { Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call }

    sequences = @wallet.ledger_entries.order(:sequence).pluck(:sequence)
    assert_equal sequences.uniq, sequences, "sequence must be unique per wallet"
    assert_equal sequences.sort, sequences
  end

  test "a round records a replayable seed" do
    result = Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call
    round = result.round.reload

    assert round.seed.present?

    replay = Games::RoundEngine.new(
      game_class: Games::Registry.math_for(@game.slug),
      bet_minor: round.bet_minor,
      rng: Games::Rng.from_seed(round.seed),
      scale: round.metadata["payout_scale"],
      buy_bonus: false
    ).call

    assert_equal round.result["grid"], replay.grid, "a stored seed must replay exactly"
  end

  test "each round gets a distinct seed" do
    a = Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 2000).call
    b = Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 2000).call
    assert_not_equal a.round.seed, b.round.seed
  end

  test "a bet below the minimum is refused and nothing is charged" do
    Games::Config.update!("min_bet_minor" => 500)
    before = @wallet.balance_minor

    error = assert_raises(Games::Error) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 100).call
    end

    assert_equal :invalid_bet, error.code
    assert_equal before, @wallet.reload.balance_minor
  end

  test "a bet above the maximum is refused" do
    error = assert_raises(Games::Error) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 10_000_000).call
    end
    assert_equal :invalid_bet, error.code
  end

  test "an unaffordable bet is refused and leaves the round to be cleaned up" do
    @wallet.update!(balance_minor: 100)
    rounds = GameRound.count

    assert_raises(Ledger::InsufficientFunds) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 5000).call
    end

    assert_equal rounds, GameRound.count, "a refused bet must not leave an orphan round"
  end

  test "an inactive game cannot be played" do
    @game.update!(status: :inactive)

    error = assert_raises(Games::Error) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call
    end
    assert_equal :game_unavailable, error.code
  end

  test "a game without registered maths cannot be played" do
    orphan = create_game(provider: @game.game_provider, slug: "ghost_game", name: "Ghost",
                         min_bet_minor: 100, max_bet_minor: 1_000_000)

    error = assert_raises(Games::Error) do
      Games::PlayService.new(game: orphan, user: @user, wallet: @wallet, bet_minor: 1000).call
    end
    assert_equal :game_not_playable, error.code
  end

  test "buying the bonus costs the stake times the configured multiple" do
    Games::Config.update!("buy_bonus_enabled" => true, "buy_bonus_cost_multiple" => 50)

    result = Games::PlayService.new(
      game: @game, user: @user, wallet: @wallet, bet_minor: 1000, buy_bonus: true
    ).call

    assert_equal 50_000, result.bet_minor
    assert_predicate result.outcome.free_spins, :any?
  end

  test "buying the bonus can be disabled from configuration" do
    Games::Config.update!("buy_bonus_enabled" => false)

    error = assert_raises(Games::Error) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000, buy_bonus: true).call
    end
    assert_equal :buy_bonus_disabled, error.code
  end

  test "the environment can force-disable the buy bonus" do
    Games::Config.update!("buy_bonus_enabled" => true)
    original = ENV["GAMES_DISABLE_BUY_BONUS"]
    ENV["GAMES_DISABLE_BUY_BONUS"] = "1"

    assert_equal false, Games::Config["buy_bonus_enabled"]
    assert_raises(Games::Error) do
      Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000, buy_bonus: true).call
    end
  ensure
    if original.nil?
      ENV.delete("GAMES_DISABLE_BUY_BONUS")
    else
      ENV["GAMES_DISABLE_BUY_BONUS"] = original
    end
  end

  test "the round records the seed, the stake and the resolved result" do
    result = Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call
    round = result.round.reload

    assert_equal "completed", round.status
    assert_equal 1000, round.bet_minor
    assert_equal result.win_minor, round.total_win_minor
    assert_equal result.outcome.grid, round.result["grid"]
    assert round.started_at.present?
    assert round.ended_at.present?
  end

  test "a real-money wallet is never touched by play" do
    real = @user.wallets.find_or_create_by!(kind: :real, currency: "BRL") do |w|
      w.status = :active
      w.balance_minor = 0
    end

    Games::PlayService.new(game: @game, user: @user, wallet: @wallet, bet_minor: 1000).call

    assert_equal 0, real.reload.balance_minor,
                 "play money must never move a real-money wallet"
  end
end
