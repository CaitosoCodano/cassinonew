class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true

      # Only the digest of the session token is stored; the raw token lives in
      # the client's HttpOnly cookie.
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_seen_at
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :sessions, :token_digest, unique: true
    add_index :sessions, :expires_at
  end
end
