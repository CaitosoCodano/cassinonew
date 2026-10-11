class CreatePasswordResetTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :password_reset_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :requested_ip

      t.timestamps
    end

    add_index :password_reset_tokens, :token_digest, unique: true
  end
end
