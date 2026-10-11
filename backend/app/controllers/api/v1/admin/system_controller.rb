module Api
  module V1
    module Admin
      # Real system measurements -- no fabricated metrics. Where a value is not
      # yet meaningful (e.g. no games registered) it is reported honestly as 0.
      class SystemController < BaseController
        # GET /api/v1/admin/system
        def show
          render json: {
            data: {
              environment: Rails.env,
              database: {
                adapter: ActiveRecord::Base.connection_db_config.adapter,
                connected: ActiveRecord::Base.connection.active?
              },
              cache_store: Rails.application.config.cache_store.to_s,
              job_adapter: ActiveJob::Base.queue_adapter.class.name,
              redis_configured: ENV["REDIS_URL"].present?,
              real_money_enabled: Platform.real_money_enabled?,
              # `::Games` is required: inside Api::V1 the bare constant would resolve to
              # the Api::V1::Games controller namespace.
              registered_adapters: ::Games::ProviderRegistry.registered.keys.sort,
              registered_games: ::Games::Registry.slugs,
              counts: {
                users: User.count,
                active_users: User.active.count,
                pending_users: User.pending.count,
                game_providers: GameProvider.count,
                active_game_providers: GameProvider.active.count,
                games: Game.count,
                active_games: Game.active.count,
                game_rounds: GameRound.count,
                open_support_requests: SupportRequest.where(status: %i[open pending]).count,
                transactions: Transaction.count,
                ledger_entries: LedgerEntry.count
              },
              integration_status: integration_status
            }
          }
        end

        private

        def integration_status
          GameProvider.order(:name).map do |provider|
            {
              slug: provider.slug,
              status: provider.status,
              health_status: provider.health_status,
              adapter_configured: provider.adapter.present?,
              integration_version: provider.integration_version,
              last_health_check_at: provider.last_health_check_at
            }
          end
        end
      end
    end
  end
end
