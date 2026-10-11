module Ledger
  # Reconciles a wallet's materialised balance against its append-only ledger.
  #
  # The ledger is the source of truth. If the two ever disagree the wallet row
  # is corrected to match the ledger (and the discrepancy is reported so it can
  # be audited / investigated).
  class Reconcile
    Report = Struct.new(:wallet, :ledger_total_minor, :wallet_balance_minor,
                        :discrepancy_minor, :consistent?, keyword_init: true)

    def self.call(wallet:)
      ledger_total = wallet.ledger_entries.sum(:amount_minor)
      wallet_balance = wallet.balance_minor

      Report.new(
        wallet: wallet,
        ledger_total_minor: ledger_total,
        wallet_balance_minor: wallet_balance,
        discrepancy_minor: wallet_balance - ledger_total,
        consistent?: wallet_balance == ledger_total
      )
    end
  end
end
