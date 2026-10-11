module Api
  module V1
    class WalletController < ApplicationController
      before_action :authenticate_active_user!

      # GET /api/v1/wallet
      def show
        wallets = current_user.wallets.order(:kind, :currency)

        render json: {
          data: {
            wallets: WalletSerializer.many(wallets),
            reconciliation: wallets.map { |wallet| reconciliation_payload(wallet) },
            real_money_enabled: Platform.real_money_enabled?
          }
        }
      end

      private

      def reconciliation_payload(wallet)
        report = Ledger::Reconcile.call(wallet: wallet)
        {
          wallet_id: wallet.id,
          consistent: report.consistent?,
          ledger_total_minor: report.ledger_total_minor,
          wallet_balance_minor: report.wallet_balance_minor,
          discrepancy_minor: report.discrepancy_minor
        }
      end
    end
  end
end
