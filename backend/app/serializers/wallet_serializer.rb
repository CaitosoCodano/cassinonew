class WalletSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      kind: record.kind,
      currency: record.currency,
      balance_minor: record.balance_minor,
      balance: record.balance,
      status: record.status,
      real_money: record.real?,
      updated_at: record.updated_at
    }
  end
end
