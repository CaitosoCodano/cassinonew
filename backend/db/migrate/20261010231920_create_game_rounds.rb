class CreateGameRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :game_rounds do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :wallet, null: false, foreign_key: true
      t.integer :bet_minor
      t.integer :total_win_minor
      t.integer :status
      t.string :seed
      t.json :state
      t.json :result
      t.json :metadata
      t.string :ip_address
      t.string :user_agent
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
