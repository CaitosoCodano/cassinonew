class CreateSupportRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :support_requests do |t|
      t.references :user, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }

      t.string :subject, null: false
      t.text :message, null: false
      # 0 general, 1 account, 2 payments, 3 technical, 4 responsible_gaming, 5 complaint
      t.integer :category, null: false, default: 0
      # 0 open, 1 pending, 2 resolved, 3 closed
      t.integer :status, null: false, default: 0
      # 0 low, 1 normal, 2 high, 3 urgent
      t.integer :priority, null: false, default: 1

      t.datetime :resolved_at
      t.timestamps
    end

    add_index :support_requests, :status
    add_index :support_requests, :category
  end
end
