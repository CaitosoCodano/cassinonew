# frozen_string_literal: true

module Games
  # Operator-facing game configuration, stored in platform_settings so it can be
  # changed from the admin area without a deploy.
  #
  # Every knob here is validated. In particular the return-to-player is clamped
  # to a sane band: a platform cannot ship a "negative game" by configuration
  # typo, and it cannot accidentally ship a generous one either.
  module Config
    KEY = "games_config"

    DEFAULTS = {
      "user_rtp_percent" => 0.27,
      "bonus_trigger_prob_percent" => 0.70,
      "min_bet_minor" => 100,
      "max_bet_minor" => 1_000_000,
      "buy_bonus_enabled" => true,
      "buy_bonus_cost_multiple" => 100,
      "default_bet_minor" => 100,
      "auto_play_max_spins" => 100,
      "allow_free_spins" => true
    }.freeze

    # Guard rails. Outside this band the setting is rejected rather than clamped
    # silently, so an operator always knows what was applied.
    LIMITS = {
      "user_rtp_percent" => (0.01..100.0),
      "bonus_trigger_prob_percent" => (0.0..100.0),
      "min_bet_minor" => (1..100_000_000),
      "max_bet_minor" => (1..1_000_000_000),
      "buy_bonus_cost_multiple" => (1..10_000),
      "default_bet_minor" => (1..100_000_000),
      "auto_play_max_spins" => (1..1000)
    }.freeze

    module_function

    def all
      stored = PlatformSetting.find_by(key: KEY)&.value
      stored = {} unless stored.is_a?(Hash)
      stored = stored.transform_keys(&:to_s)

      DEFAULTS.merge(stored.slice(*DEFAULTS.keys)).merge(read_env_overrides)
    end

    # Environment overrides exist for emergency kill-switches only. They always
    # win over the database so an operator can disable play money instantly.
    def read_env_overrides
      overrides = {}
      overrides["buy_bonus_enabled"] = false if truthy_env?("GAMES_DISABLE_BUY_BONUS")
      overrides["allow_free_spins"] = false if truthy_env?("GAMES_DISABLE_FREE_SPINS")
      overrides
    end

    def truthy_env?(key)
      %w[1 true yes on].include?(ENV[key].to_s.strip.downcase)
    end

    def [](key)
      all[key.to_s]
    end

    # Validates and persists a partial update. Raises Config::Invalid so the
    # admin controller can answer 422 with the offending field.
    class Invalid < StandardError
      attr_reader :field, :reason

      def initialize(field, reason)
        @field = field
        @reason = reason
        super("#{field}: #{reason}")
      end
    end

    def update!(attributes)
      current = all
      supplied = attributes.to_h.transform_keys(&:to_s)

      # Unknown keys are rejected rather than dropped. A typo in an admin form
      # has to be loud, otherwise an operator believes a setting changed when
      # nothing happened.
      unknown = supplied.keys - DEFAULTS.keys
      unless unknown.empty?
        raise Invalid.new(unknown.sort.join(", "), "is not a configurable game setting")
      end

      merged = current.merge(supplied)

      merged.each do |key, value|
        validate!(key, value)
      end

      if merged["min_bet_minor"] > merged["max_bet_minor"]
        raise Invalid.new("min_bet_minor", "must not exceed max_bet_minor")
      end

      setting = PlatformSetting.find_or_initialize_by(key: KEY)
      setting.category = "games"
      setting.description = "Game maths, RTP and feature switches"
      setting.editable = true
      setting.value = merged
      setting.save!
      merged
    end

    def validate!(key, value)
      unless DEFAULTS.key?(key)
        raise Invalid.new(key, "is not a configurable game setting")
      end

      case DEFAULTS[key]
      when true, false
        unless [true, false, 0, 1, "true", "false"].include?(value)
          raise Invalid.new(key, "must be a boolean")
        end
      when Integer
        unless value.to_s.match?(/\A-?\d+\z/)
          raise Invalid.new(key, "must be a whole number")
        end

        integer = Integer(value)
        range = LIMITS[key]
        raise Invalid.new(key, "must be between #{range.min} and #{range.max}") unless range.cover?(integer)

        if (ok = Integer(value, exception: false)) && integer != ok
          raise Invalid.new(key, "must be a whole number")
        end
      when Float
        float = Float(value, exception: false)
        raise Invalid.new(key, "must be a number") unless float

        range = LIMITS[key]
        raise Invalid.new(key, "must be between #{range.min} and #{range.max}") unless range.cover?(float)
      end
    end
  end
end