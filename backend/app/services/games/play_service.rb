# frozen_string_literal: true

module Games
  # Plays one round end to end.
  #
  # Money handling goes through Ledger::Post, so every spin produces an
  # immutable Transaction plus an append-only LedgerEntry and the wallet can
  # always be reconciled from history. The debit happens first and wins the
  # race for funds; the credit happens second and can never leave the wallet
  # negative.
  class PlayService
    Result = Struct.new(:round, :outcome, :wallet, :bet_minor, :win_minor, :balance_minor, keyword_init: true)

    def initialize(game:, user:, wallet:, bet_minor:, buy_bonus: false, ip_address: nil, user_agent: nil)
      @game = game
      @user = user
      @wallet = wallet
      @bet_minor = Integer(bet_minor)
      @buy_bonus = buy_bonus
      @ip_address = ip_address
      @user_agent = user_agent
      @config = Games::Config.all
    end

    # Round record, stake debit and win credit all commit together. If the
    # player cannot cover the stake, nothing at all is written: no orphan
    # round, no ledger entry, no balance movement.
    def call
      validate!
      ensure_balance!

      seed = Games::Rng.generate_seed
      rng = Games::Rng.from_seed(seed)
      math = Games::Registry.math_for(@game.slug)
      scale = Games::RtpCalibrator.scale_for(@game.slug, @config["user_rtp_percent"])

      outcome = Games::RoundEngine.new(
        game_class: math,
        bet_minor: effective_bet,
        rng: rng,
        scale: scale,
        buy_bonus: @buy_bonus
      ).call

      win_minor = resolve_win_minor(outcome)

      round = nil
      ActiveRecord::Base.transaction do
        round = GameRound.create!(
          game: @game,
          user: @user,
          wallet: @wallet,
          bet_minor: effective_bet,
          total_win_minor: win_minor,
          status: :in_progress,
          seed: seed,
          state: { "phase" => "spinning", "buy_bonus" => @buy_bonus },
          result: {},
          metadata: {
            "rtp_target_percent" => @config["user_rtp_percent"],
            "payout_scale" => scale.round(6)
          },
          ip_address: @ip_address,
          user_agent: @user_agent,
          started_at: Time.current
        )

        post_bet(round)
        post_win(round, win_minor) if win_minor.positive?

        round.update!(
          status: :completed,
          result: outcome.to_h.merge("win_minor" => win_minor,
                                     "bet_minor" => effective_bet,
                                     "base_bet_minor" => @bet_minor),
          state: { "phase" => "complete", "buy_bonus" => @buy_bonus },
          ended_at: Time.current
        )
      end

      Result.new(
        round: round,
        outcome: outcome,
        wallet: @wallet.reload,
        bet_minor: effective_bet,
        win_minor: win_minor,
        balance_minor: @wallet.balance_minor
      )
    end

    private

    def validate!
      unless Games::Registry.registered?(@game.slug)
        raise Error.new(:game_not_playable, "#{@game.slug} has no registered maths.")
      end

      unless @game.active?
        raise Error.new(:game_unavailable, "#{@game.slug} is not currently available.")
      end

      if @bet_minor < @config["min_bet_minor"] || @bet_minor > @config["max_bet_minor"]
        raise Error.new(:invalid_bet, "Bet must be between #{@config['min_bet_minor']} and #{@config['max_bet_minor']} credits.")
      end

      return unless @buy_bonus

      unless @config["buy_bonus_enabled"]
        raise Error.new(:buy_bonus_disabled, "Buying the bonus is currently disabled.")
      end

      # The player picks a normal bet; buying the bonus costs that bet times the
      # configured multiple. Only the resulting total has to fit the wallet and
      # the max-bet ceiling.
      cost = buy_bonus_cost
      if cost > @config["max_bet_minor"] * @config["buy_bonus_cost_multiple"]
        raise Error.new(:buy_bonus_too_large, "Buying the bonus at this bet exceeds the maximum stake.")
      end
    end

    # What the round actually costs the wallet.
    def buy_bonus_cost
      @bet_minor * @config["buy_bonus_cost_multiple"]
    end

    def ensure_balance!
      return if @wallet.usable?

      raise Error.new(:wallet_unusable, "This wallet cannot be used for play.")
    end

    # The bonus is priced at cost x multiple. When bought, that larger amount is
    # the wager for the round (and the round records it as such).
    def effective_bet
      @buy_bonus ? buy_bonus_cost : @bet_minor
    end

    # Wins are quoted in "line bet" units, so scale to whole minor units.
    # A bought bonus costs bet x multiple but returns the free-spin maths
    # divided by that same multiple: the feature is priced, never generous.
    def resolve_win_minor(outcome)
      units = outcome.total_units.to_f
      scaled = @buy_bonus ? units * buy_bonus_payout_ratio : units
      scaled.round(2).to_i
    end

    def buy_bonus_payout_ratio
      # A bought bonus returns the same maths as a natural trigger, priced
      # against the full cost the player paid.
      1.0 / @config["buy_bonus_cost_multiple"].to_f
    end

    def post_bet(round)
      Ledger::Post.call(
        wallet: @wallet,
        amount_minor: -effective_bet,
        kind: :bet,
        idempotency_key: "game_round:#{round.id}:bet",
        description: "#{@game.name} — wager",
        initiated_by: @user,
        provider: "internal",
        external_reference: round.id.to_s,
        metadata: { "game_slug" => @game.slug, "buy_bonus" => @buy_bonus }
      )
    end

    def post_win(round, win_minor)
      Ledger::Post.call(
        wallet: @wallet,
        amount_minor: win_minor,
        kind: :win,
        idempotency_key: "game_round:#{round.id}:win",
        description: "#{@game.name} — win",
        initiated_by: @user,
        provider: "internal",
        external_reference: round.id.to_s,
        metadata: { "game_slug" => @game.slug, "buy_bonus" => @buy_bonus }
      )
    end
  end
end