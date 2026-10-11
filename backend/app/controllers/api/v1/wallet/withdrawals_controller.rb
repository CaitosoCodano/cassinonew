module Api
  module V1
    module Wallet
      # Withdrawals are intentionally NOT implemented. See DepositsController.
      class WithdrawalsController < ApplicationController
        before_action :authenticate_active_user!

        def create
          render_error(
            code: "not_implemented",
            message: "Withdrawals are not available. No payout provider is configured for this deployment.",
            status: :not_implemented,
            details: [{
              reason: "payment_provider_not_configured",
              real_money_enabled: Platform.real_money_enabled?,
              required: "Identity verification, anti-fraud controls and a licensed payout rail."
            }]
          )
        end
      end
    end
  end
end
