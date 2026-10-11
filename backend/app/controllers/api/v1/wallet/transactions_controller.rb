module Api
  module V1
    module Wallet
      class TransactionsController < ApplicationController
        before_action :authenticate_active_user!

        # GET /api/v1/wallet/transactions
        def index
          scope = current_user.transactions.recent
          scope = scope.where(wallet_id: params[:wallet_id]) if params[:wallet_id].present?
          scope = scope.where(kind: params[:kind]) if params[:kind].present?
          scope = scope.where(status: params[:status]) if params[:status].present?

          records, meta = paginate(scope)
          render_collection(records: records, serializer: TransactionSerializer, meta: meta)
        end

        # GET /api/v1/wallet/transactions/:id
        def show
          transaction = current_user.transactions.find(params[:id])
          render_resource(transaction, serializer: TransactionSerializer)
        end
      end
    end
  end
end
