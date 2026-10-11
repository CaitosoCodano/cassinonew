module Api
  module V1
    module Admin
      # Administrative wallet adjustments. The ONLY way an admin can change a
      # balance is through Ledger::Post, which is atomic, append-only and
      # idempotent, and records the acting admin. Balances are never set
      # directly.
      class WalletAdjustmentsController < BaseController
        # POST /api/v1/admin/wallets/:wallet_id/adjustments
        def create
          wallet = ::Wallet.find(params[:wallet_id])

          result = Ledger::Post.call(
            wallet: wallet,
            amount_minor: params.require(:amount_minor).to_i,
            kind: params.fetch(:kind, "adjustment"),
            description: params[:description],
            idempotency_key: params[:idempotency_key],
            initiated_by: current_user,
            metadata: { admin_adjustment: true, admin_id: current_user.id }
          )

          Audit::Record.call(
            actor: current_user,
            action: "admin.wallet_adjusted",
            auditable: wallet,
            metadata: {
              amount_minor: result.transaction.amount_minor,
              transaction_id: result.transaction.id,
              replayed: result.replayed?
            },
            request: request
          )

          render json: {
            data: {
              wallet: WalletSerializer.one(result.wallet),
              transaction: TransactionSerializer.one(result.transaction),
              replayed: result.replayed?
            }
          }, status: :created
        rescue Ledger::Error => e
          render_error(code: "ledger_rejected", message: e.message, status: :unprocessable_content)
        end
      end
    end
  end
end
