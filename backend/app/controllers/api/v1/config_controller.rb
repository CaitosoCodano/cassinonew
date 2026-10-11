module Api
  module V1
    # Public, non-authenticated configuration consumed by the web client at
    # boot. Contains no secrets and no fabricated metrics.
    class ConfigController < ApplicationController
      # GET /api/v1/config
      def show
        render json: {
          data: {
            brand: {
              name: Platform::BRAND_NAME,
              descriptor: Platform::BRAND_DESCRIPTOR,
              support_email: Platform::SUPPORT_EMAIL
            },
            real_money_enabled: Platform.real_money_enabled?,
            minimum_age: PlatformSetting.value_for("minimum_age", 18),
            currencies: currency_configuration,
            feature_flags: FeatureFlag.on.pluck(:key),
            self_exclusion: {
              cool_off_hours: PlatformSetting.value_for("cool_off_hours", 24),
              self_exclusion_min_days: PlatformSetting.value_for("self_exclusion_min_days", 1)
            },
            legal: {
              content_requires_review: true,
              note: "Legal copy is configurable and must be reviewed for the operating jurisdiction."
            }
          }
        }
      end

      private

      def currency_configuration
        [
          { code: "VCR", type: "virtual", label: "Virtual credits", enabled: true },
          { code: "EUR", type: "real", label: "Euro", enabled: Platform.real_money_enabled? }
        ]
      end
    end
  end
end
