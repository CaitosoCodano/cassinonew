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

    # One active limit per user, kind and period; superseded rows stay in the
    # table but drop out of the index so the unique constraint only applies to
    # the current one.
    #
    # The predicate names the column on its own instead of comparing it to 1.
    # SQLite stores booleans as integers so `active = 1` is accepted there, but
    # PostgreSQL has a real boolean type and rejects the comparison outright:
    # "operator does not exist: boolean = integer". A bare `WHERE active` means
    # the same thing to both.
    add_index :responsible_gaming_limits, %i[user_id kind period], unique: true,
               where: "active", name: "idx_rg_limits_active_unique"
  end
end
