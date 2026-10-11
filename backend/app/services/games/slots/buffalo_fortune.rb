# frozen_string_literal: true

module Games
  module Slots
    # Buffalo Fortune - 5x3, 20 fixed paylines, buffalo/west theme.
    #
    # The buffalo is the super-symbol: three or more anywhere multiply the
    # whole spin. That is the only route to a meaningful return, matching the
    # "rich, volatile, mostly-losing" shape the operator asked for.
    class BuffaloFortune < BaseSlot
      WILD = "WILD"
      SCATTER = "SCATTER"
      BUFFALO = "BUFF"

      # prettier-ignore
      STRIPS = [
        [
          %w[10 10 10 10 10 J J J Q Q K K A A],
          %w[EAGLE EAGLE BISON BISON BUFF BUFF],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 10 10 J J J Q Q Q K K A],
          %w[EAGLE EAGLE BISON BISON BUFF BUFF],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 10 J J J Q Q Q K K A A],
          %w[EAGLE BISON BISON BUFF BUFF BUFF],
          %w[WILD SCATTER]
        ],
        [
          %w[10 10 J J J Q Q Q K K A A A],
          %w[EAGLE EAGLE BISON BUFF BUFF BUFF],
          %w[WILD SCATTER]
        ],
        [
          %w[10 J J Q Q K K A A A A A A A],
          %w[EAGLE BISON BUFF BUFF BUFF BUFF],
          %w[SCATTER WILD]
        ]
      ].freeze

      PAYTABLE = {
        "10" => [2, 5, 20],
        "j" => [3, 8, 30],
        "q" => [4, 10, 40],
        "k" => [5, 12, 50],
        "a" => [8, 20, 80],
        "eagle" => [12, 30, 120],
        "bison" => [20, 50, 250],
        "buff" => [30, 100, 600]
      }.freeze

      SCATTER_PAYS = { 3 => 10, 4 => 50, 5 => 250 }.freeze
      SCATTER_FREE_SPINS = { 3 => 10, 4 => 15, 5 => 25 }.freeze

      # Buffalo "stampede": every 3 buffalos found multiplies the total win.
      BUFFALO_TIERS = { 3 => 2, 4 => 5, 5 => 10, 6 => 25, 7 => 50, 8 => 100, 9 => 250, 10 => 500 }.freeze

      # Authored paytable scale. The raw paytable above returns ~62% on its own, so
# this lifts the native game onto a standard ~96% RTP. The operator's RTP
# setting is applied on top of that at play time. Recalibrate with
#   rails runner tmp/native_rtp.rb
# if the strips or paytable are ever edited.
PAYTABLE_SCALE = 1.545

BONUS_MULTIPLIER_STEP = 1
      BONUS_MULTIPLIER_CAP = 8

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

      SYMBOLS = %w[10 J Q K A EAGLE BISON BUFF WILD SCATTER].freeze

      def self.metadata
        {
          "theme" => "buffalo",
          "title" => "Buffalo Fortune",
          "rows" => ROWS,
          "reels" => REELS,
          "paylines" => PAYLINES.size,
          "symbols" => symbol_catalog,
          "features" => %w[free_spins buffalo_stampede buy_bonus],
          "audio_theme" => "buffalo"
        }
      end

      def self.symbol_catalog
        [
          { "key" => "10", "label" => "10" },
          { "key" => "j", "label" => "J" },
          { "key" => "q", "label" => "Q" },
          { "key" => "k", "label" => "K" },
          { "key" => "a", "label" => "A" },
          { "key" => "eagle", "label" => "Eagle" },
          { "key" => "bison", "label" => "Bison" },
          { "key" => "buff", "label" => "Buffalo" },
          { "key" => "w", "label" => "Wild" },
          { "key" => "scatter", "label" => "Scatter" }
        ]
      end
    end
  end
end