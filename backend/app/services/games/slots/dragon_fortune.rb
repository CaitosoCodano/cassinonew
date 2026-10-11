# frozen_string_literal: true

module Games
  module Slots
    # Dragon Fortune - 5x3, 20 fixed paylines, dragon/wild theme.
    #
    # Symbol weights are read top to bottom. Low symbols are plentiful; the
    # premium dragons are rare, which is what makes the 5-of-a-kind and the
    # free-spin bonus the only meaningful paths to a return.
    class DragonFortune < BaseSlot
      WILD = "WILD"
      SCATTER = "SCATTER"

      # prettier-ignore
      STRIPS = [
        # Reel 0 - friendliest
        [
          %w[10 10 10 10 10 J J J Q Q Q K K A A],
          %w[DG DG DG DR DR DG DR DG DG DR DR],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 10 10 J J J J Q Q Q K K A],
          %w[DG DG DG DG DR DR DG DG DR DR DG],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 10 J J J Q Q Q Q K K K A],
          %w[DG DG DG DR DR DR DG DG DG DR DR],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 J J J Q Q Q K K K K A A],
          %w[DG DG DG DG DR DG DR DR DG DR DG],
          %w[WILD SCATTER]
        ],
        # Reel 4 - harshest, standard for a 20-line game
        [
          %w[10 J J Q Q Q K K K A A A A],
          %w[DR DR DG DG DG DR DG DG DR DG DR],
          %w[SCATTER WILD]
        ]
      ].freeze

      # paytable[base] = [3 of a kind, 4 of a kind, 5 of a kind] in line bets
      PAYTABLE = {
        "10" => [2, 5, 20],
        "j" => [3, 8, 30],
        "q" => [4, 10, 40],
        "k" => [6, 15, 60],
        "a" => [10, 25, 100],
        "dg" => [15, 40, 200],  # green dragon
        "dr" => [25, 75, 400],  # red dragon
        "w" => nil               # handled by wild substitution
      }.freeze

      # Scatter pays anywhere, in line-bet units, and awards free spins.
      SCATTER_PAYS = { 3 => 10, 4 => 50, 5 => 200 }.freeze
      SCATTER_FREE_SPINS = { 3 => 8, 4 => 12, 5 => 20 }.freeze

      # Authored paytable scale. The raw paytable above returns ~123% on its own,
# so this brings the native game onto a standard ~96% RTP. The operator's RTP
# setting is applied on top of that at play time. Recalibrate with
#   rails runner tmp/native_rtp.rb
# if the strips or paytable are ever edited.
PAYTABLE_SCALE = 0.778

# The bonus ladder: each consecutive free spin raises the win multiplier.
      BONUS_MULTIPLIER_STEP = 1
      BONUS_MULTIPLIER_CAP = 10

      # 20 fixed paylines over a 5x3 grid. Each entry is [row, col] pairs.
      # prettier-ignore
      PAYLINES = [
        [[0,0],[0,1],[0,2],[0,3],[0,4]],
        [[1,0],[1,1],[1,2],[1,3],[1,4]],
        [[2,0],[2,1],[2,2],[2,3],[2,4]],
        [[0,0],[1,1],[2,2],[1,3],[0,4]],
        [[2,0],[1,1],[0,2],[1,3],[2,4]],
        [[0,1],[0,2],[0,3],[1,4],[2,4]],
        [[1,0],[0,1],[1,2],[0,3],[1,4]],
        [[1,1],[2,1],[1,2],[2,2],[1,3]],
        [[0,0],[1,0],[2,0],[1,1],[2,1]],
        [[2,0],[1,0],[0,0],[1,1],[0,1]],
        [[2,0],[1,0],[0,0],[0,1],[0,2]],
        [[0,0],[0,1],[1,0],[1,1],[2,0]],
        [[0,2],[0,3],[0,4],[1,2],[1,3]],
        [[1,2],[1,3],[1,4],[0,2],[0,3]],
        [[2,2],[2,3],[2,4],[1,2],[1,3]],
        [[1,1],[0,1],[1,2],[2,2],[1,3]],
        [[0,3],[1,2],[2,1],[1,0],[0,0]],
        [[1,3],[0,2],[1,1],[2,0],[1,0]],
        [[2,3],[1,2],[2,1],[1,0],[2,0]],
        [[1,0],[1,1],[0,1],[0,2],[0,3]],
      ].freeze

      SYMBOLS = %w[10 J Q K A DG DR WILD SCATTER].freeze

      # Per-game presentation metadata surfaced to the client.
      def self.metadata
        {
          "theme" => "dragon",
          "title" => "Dragon Fortune",
          "rows" => ROWS,
          "reels" => REELS,
          "paylines" => PAYLINES.size,
          "symbols" => symbol_catalog,
          "features" => %w[free_spins scatter_multiplier buy_bonus],
          "audio_theme" => "dragon"
        }
      end

      def self.symbol_catalog
        [
          { "key" => "10", "label" => "10" },
          { "key" => "j", "label" => "J" },
          { "key" => "q", "label" => "Q" },
          { "key" => "k", "label" => "K" },
          { "key" => "a", "label" => "A" },
          { "key" => "dg", "label" => "Green Dragon" },
          { "key" => "dr", "label" => "Red Dragon" },
          { "key" => "w", "label" => "Wild" },
          { "key" => "scatter", "label" => "Scatter" }
        ]
      end
    end
  end
end