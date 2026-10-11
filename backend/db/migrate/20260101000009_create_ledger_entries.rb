class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    # Append-only: rows are never updated or deleted (enforced in the model).
    # `sequence` gives a per-wallet monotonic ordering for reconciliation.
    create_table :ledger_entries do |t|
      t.references :wallet, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true

      t.bigint :sequence, null: false
      t.bigint :amount_minor, null: false
      t.bigint :balance_after_minor, null: false
      t.string :entry_type, null: false
      t.json :metadata, null: false, default: {}

      # Append-only: created_at only, no updated_at.
      t.datetime :created_at, null: false
    end

    add_index :ledger_entries, %i[wallet_id sequence], unique: true
    add_index :ledger_entries, %i[wallet_id created_at]
  end
end
