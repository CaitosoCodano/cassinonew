class TransactionSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      kind: record.kind,
      status: record.status,
      amount_minor: record.amount_minor,
      amount: format("%.2f", record.amount_minor / 100.0),
      currency: record.currency,
      balance_before_minor: record.balance_before_minor,
      balance_after_minor: record.balance_after_minor,
      description: record.description,
      provider: record.provider,
      external_reference: record.external_reference,
      processed_at: record.processed_at,
      created_at: record.created_at
    }
  end
end
