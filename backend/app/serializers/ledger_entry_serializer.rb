class LedgerEntrySerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      sequence: record.sequence,
      entry_type: record.entry_type,
      amount_minor: record.amount_minor,
      balance_after_minor: record.balance_after_minor,
      transaction_id: record.transaction_id,
      created_at: record.created_at
    }
  end
end
