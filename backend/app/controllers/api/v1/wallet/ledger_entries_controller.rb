module Api
  module V1
    module Wallet
      class LedgerEntriesController < ApplicationController
        before_action :authenticate_active_user!

        # GET /api/v1/wallet/ledger
        # The append-only ledger is exposed read-only for transparency.
        def index
          scope = current_user.ledger_entries.order(created_at: :desc)
          scope = scope.where(wallet_id: params[:wallet_id]) if params[:wallet_id].present?

          records, meta = paginate(scope)
          render_collection(records: records, serializer: LedgerEntrySerializer, meta: meta)
        end
      end
    end
  end
end
