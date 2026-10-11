class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.references :wallet, null: false, foreign_key: true

      # 0 pending, 1 active, 2 ended, 3 expired, 4 terminated
      t.integer :status, null: false, default: 0

      t.string :provider_session_reference
      t.string :token_digest
      t.string :ip_address
      t.string :user_agent
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :expires_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :game_sessions, :status
    add_index :game_sessions, :provider_session_reference
    add_index :game_sessions, %i[user_id status]
  end
end
