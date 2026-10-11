module Api
  module V1
    module Wallet
      # Deposits are intentionally NOT implemented: no payment provider is
      # integrated and real-money functionality is disabled. This endpoint
      # exists so the contract is stable, and always answers 501.
      class DepositsController < ApplicationController
        before_action :authenticate_active_user!

        def create
          render_error(
            code: "not_implemented",
            message: "Deposits are not available. No payment provider is configured for this deployment.",
            status: :not_implemented,
            details: [{
              reason: "payment_provider_not_configured",
              real_money_enabled: Platform.real_money_enabled?,
              required: "A licensed, PCI-compliant payment integration plus jurisdiction review."
            }]
          )
        end
      end
    end
  end
end
