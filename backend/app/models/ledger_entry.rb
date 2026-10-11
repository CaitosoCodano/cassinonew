class LedgerEntry < ApplicationRecord
  # Append-only ledger. Rows must never be updated or destroyed.
  belongs_to :wallet
  # Renamed from `transaction` to avoid clashing with ActiveRecord::Base.transaction.
  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :transaction_id,
                                     inverse_of: :ledger_entries

  validates :sequence, presence: true, uniqueness: { scope: :wallet_id }
  validates :amount_minor, :balance_after_minor, presence: true,
                                                numericality: { only_integer: true }

  # Persisted rows are read-only. `readonly?` is consulted by save/destroy and
  # ActiveRecord will raise ActiveRecord::ReadOnlyRecord on any attempt to
  # mutate an existing entry.
  def readonly?
    persisted?
  end

  def credit?
    amount_minor.positive?
  end
end
