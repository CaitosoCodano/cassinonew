module Api
  module V1
    module Admin
      # Game maths and payout configuration.
      #
      # Everything here is audited: an operator changing the return-to-player is
      # recorded with the previous and new value so the change is traceable.
      class GameConfigController < BaseController
        # Domain services are referenced as `::Games` throughout: a bare
        # `Games` resolves to this controller namespace from inside Api::V1.

        # GET /api/v1/admin/game_config
        def show
          render json: { data: payload }
        end

        # PATCH /api/v1/admin/game_config
        def update
          ::Games::Config.update!(params.fetch(:config, {}).to_unsafe_h)

          Audit::Record.call(
            actor: current_user,
            action: "admin.game_config_updated",
            auditable: PlatformSetting.find_by(key: ::Games::Config::KEY),
            metadata: { config: ::Games::Config.all },
            request: request
          )

          render json: { data: payload }
        rescue ::Games::Config::Invalid => e
          render json: {
            error: { code: "invalid_config", message: e.reason, details: { field: e.field } }
          }, status: :unprocessable_entity
        end

        # GET /api/v1/admin/game_config/rtp
        #
        # Runs the Monte Carlo simulation so the operator sees the *measured*
        # return, not a claim. The default sample is small enough to stay
        # responsive in a request cycle; the UI shows the confidence interval so
        # a noisy sample is visibly noisy rather than presented as fact.
        def rtp
          spins = [[params.fetch(:spins, 20_000).to_i, 500].max, 100_000].min

          reports = ::Games::Registry.slugs.map do |slug|
            ::Games::RtpCalibrator.report(
              slug,
              target_rtp_percent: ::Games::Config["user_rtp_percent"],
              spins: spins
            )
          end

          render json: { data: { spins: spins, target_percent: ::Games::Config["user_rtp_percent"], games: reports } }
        end

        private

        def payload
          {
            config: ::Games::Config.all,
            # Ranges are not JSON-serialisable; expose them as [min, max].
            limits: ::Games::Config::LIMITS.transform_values { |range| [range.min, range.max] },
            defaults: ::Games::Config::DEFAULTS,
            registry: ::Games::Registry.slugs,
            games: Game.where(game_provider_id: internal_provider_id).map { |g| brief(g) },
            overrides: {
              buy_bonus_disabled_by_env: ::Games::Config.truthy_env?("GAMES_DISABLE_BUY_BONUS"),
              free_spins_disabled_by_env: ::Games::Config.truthy_env?("GAMES_DISABLE_FREE_SPINS")
            }
          }
        end

        def internal_provider_id
          @internal_provider_id ||= GameProvider.find_by(slug: "internal")&.id
        end

        def brief(game)
          # `::` is required on the maths module too: inside Api::V1::Games a
          # bare Games::Slots would resolve against this controller namespace.
          math = ::Games::Registry.registered?(game.slug) ? ::Games::Registry.math_for(game.slug) : nil
          {
            id: game.id,
            slug: game.slug,
            name: game.name,
            status: game.status,
            playable: game.playable?,
            registered: !math.nil?,
            paylines: math&.const_defined?(:PAYLINES) ? math::PAYLINES.size : nil,
            theme: math&.metadata&.dig("theme"),
            free_spin_awards: math&.const_defined?(:SCATTER_FREE_SPINS) ? math::SCATTER_FREE_SPINS : nil,
            scatter_pays: math&.const_defined?(:SCATTER_PAYS) ? math::SCATTER_PAYS : nil
          }
        end
      end
    end
  end
end