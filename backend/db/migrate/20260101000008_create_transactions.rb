class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :wallet, null: false, foreign_key: true

      # 0 deposit, 1 withdrawal, 2 bet, 3 win, 4 adjustment, 5 transfer,
      # 6 refund, 7 bonus, 8 reversal
      t.integer :kind, null: false
      # 0 pending, 1 completed, 2 failed, 3 reversed, 4 cancelled
      t.integer :status, null: false, default: 0

      # Signed integer minor units. Positive = credit to the wallet.
      t.bigint :amount_minor, null: false
      t.string :currency, null: false, limit: 3

      t.bigint :balance_before_minor, null: false
      t.bigint :balance_after_minor, null: false

      # Idempotency: unique when present. See IdempotencyRecord for higher-level
      # request de-duplication.
      t.string :idempotency_key
      t.string :provider
      t.string :external_reference
      t.string :description
      t.json :metadata, null: false, default: {}
      t.references :initiated_by, foreign_key: { to_table: :users }
      t.datetime :processed_at

      t.timestamps
    end

    add_index :transactions, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
    add_index :transactions, %i[wallet_id created_at]
    add_index :transactions, %i[wallet_id status]
    add_index :transactions, :kind
  end
end
