# frozen_string_literal: true

module Games
  # Domain error raised when a round cannot be played.
  #
  # The code is part of the API contract: the controller maps it straight onto
  # the response body, so clients can branch on a stable string instead of
  # parsing a human-readable message.
  #
  #   :game_not_playable  - no maths registered for this slug
  #   :game_unavailable   - the title is not active
  #   :invalid_bet        - stake outside the configured range
  #   :buy_bonus_disabled - the feature is switched off
  #   :buy_bonus_too_large- the purchased stake exceeds the ceiling
  #   :wallet_unusable    - the wallet is frozen or closed
  class Error < StandardError
    CODES = %i[
      game_not_playable
      game_unavailable
      invalid_bet
      buy_bonus_disabled
      buy_bonus_too_large
      wallet_unusable
    ].freeze

    attr_reader :code

    def initialize(code, message)
      raise ArgumentError, "unknown error code #{code}" unless CODES.include?(code)

      @code = code
      super(message)
    end
  end
end