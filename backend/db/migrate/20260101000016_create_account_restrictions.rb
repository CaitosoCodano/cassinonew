class CreateAccountRestrictions < ActiveRecord::Migration[8.1]
  def change
    create_table :account_restrictions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :imposed_by, foreign_key: { to_table: :users }
      t.references :lifted_by, foreign_key: { to_table: :users }

      # 0 self_exclusion, 1 cool_off, 2 suspension, 3 ban, 4 deposit_block, 5 wager_block
      t.integer :kind, null: false
      # 0 active, 1 expired, 2 lifted
      t.integer :status, null: false, default: 0

      t.text :reason
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.datetime :lifted_at

      t.timestamps
    end

    add_index :account_restrictions, %i[user_id status]
    add_index :account_restrictions, :kind
  end
end
