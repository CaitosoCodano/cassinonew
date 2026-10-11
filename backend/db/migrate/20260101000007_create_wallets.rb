class CreateWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :wallets do |t|
      t.references :user, null: false, foreign_key: true

      # 0 virtual (play / promotional credits), 1 real (not enabled by default).
      # Virtual and real balances are deliberately kept in separate rows.
      t.integer :kind, null: false, default: 0
      t.string :currency, null: false, limit: 3, default: "VCR" # virtual credit unit

      # Balances are integer minor units. Never floats.
      t.bigint :balance_minor, null: false, default: 0

      # 0 active, 1 frozen, 2 closed
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :wallets, %i[user_id kind currency], unique: true
    add_index :wallets, :kind
  end
end
