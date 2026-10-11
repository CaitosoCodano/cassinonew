class CreateResponsibleGamingLimits < ActiveRecord::Migration[8.1]
  def change
    create_table :responsible_gaming_limits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :set_by, foreign_key: { to_table: :users }

      # 0 deposit, 1 loss, 2 wager, 3 session_time, 4 session_count
      t.integer :kind, null: false
      # 0 daily, 1 weekly, 2 monthly, 3 session, 4 permanent
      t.integer :period, null: false, default: 0

      t.bigint :amount_minor
      t.bigint :duration_seconds
      t.boolean :active, null: false, default: true
      t.datetime :effective_from, null: false
      t.datetime :effective_until

      t.timestamps
    end

    add_index :responsible_gaming_limits, %i[user_id kind period], unique: true,
               where: "active = 1", name: "idx_rg_limits_active_unique"
  end
end
