class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.references :role, null: false, foreign_key: true

      # pending = registered but not verified, active = usable, suspended = blocked
      # by an operator, closed = user-initiated deletion.
      t.integer :status, null: false, default: 0

      t.datetime :email_verified_at
      t.datetime :last_sign_in_at
      t.integer :failed_sign_in_attempts, null: false, default: 0
      t.datetime :locked_at
      t.datetime :closed_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :status
  end
end
