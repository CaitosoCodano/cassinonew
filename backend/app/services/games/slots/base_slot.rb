# frozen_string_literal: true

module Games
  module Slots
    # Shared math for 5-reel / 3-row payline slots.
    #
    # Design rules (deliberately boring and auditable):
    #   * The server owns every random decision. The client only animates the
    #     result it is given; it cannot influence or predict an outcome.
    #   * Reel strips are explicit symbol weights, so a reviewer can read the
    #     distribution without running anything.
    #   * Winning maths goes through a single payout scale factor derived from
    #     the operator-configured return-to-player, which keeps the same reel
    #     behaviour while letting RTP be tuned from the admin area.
    class BaseSlot
      ROWS = 3
      REELS = 5

      # A symbol weight entry is [symbol, weight].
      class ReelStrip
        include Enumerable

        attr_reader :entries, :total_weight

        def initialize(entries)
          @entries = entries
          @total_weight = entries.sum { |(_, weight)| weight }
          freeze
        end

        def each(&block)
          entries.each(&block)
          self
        end

        def size
          entries.size
        end

        # Picks one symbol using the supplied RNG. Uniform in *weight*, not in
        # symbol count, so designers control volatility directly.
        def pick(rng)
          target = rng.rand(total_weight)
          cursor = 0
          entries.each do |symbol, weight|
            cursor += weight
            return symbol if target < cursor
          end
          entries.last.first
        end

        def symbols
          entries.map(&:first)
        end
      end

      class << self
        # Returns a full 5x3 grid (array of reels, each an array of 3 symbols).
        def generate_grid(rng, strips:)
          strips.map { |strip| Array.new(ROWS) { strip.pick(rng) } }
        end

        # Evaluates every payline against the grid.
        #
        # Returns a hash with:
        #   :total_units  - total win in "line bet" units (multiply by bet/20)
        #   :line_wins    - per-line detail for the client to highlight
        def evaluate_lines(grid, paylines:, paytable:, wild:)
          wins = []

          paylines.each_with_index do |line, index|
            symbols = line.map { |row, col| grid[col][row] }

            base, count = leading_match(symbols, wild)
            next if base.nil? || count < 3

            pays = paytable[base]
            next if pays.nil?

            value = pays[count - 3]
            next if value.nil? || value.zero?

            wins << {
              "index" => index,
              "cells" => line.first(count).map { |row, col| [col, row] },
              "symbol" => base,
              "count" => count,
              "value" => value
            }
          end

          { total_units: wins.sum { |w| w["value"] }, lines: wins, line_bets: paylines.size }
        end

        # Returns [base_symbol_key, leading_match_length].
        #
        # A wild substitutes for whatever the line is otherwise building, so
        # the base symbol is the first non-wild symbol that starts the run.
        # A line of nothing but wilds has no base symbol to pay against.
        def leading_match(symbols, wild)
          base = symbols.find { |s| s != wild }
          return [nil, 0] if base.nil?

          count = 0
          symbols.each do |symbol|
            break unless symbol == base || symbol == wild

            count += 1
          end

          [base.to_s.downcase, count]
        end

        # Scatter symbols pay anywhere on the grid and may award free spins.
        def evaluate_scatters(grid, scatter:)
          positions = []
          grid.each_with_index do |column, col|
            column.each_with_index do |symbol, row|
              positions << [col, row] if symbol == scatter
            end
          end
          { count: positions.size, positions: positions }
        end
      end
    end
  end
end