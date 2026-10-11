class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :game_provider, null: false, foreign_key: true

      t.string :slug, null: false
      t.string :name, null: false
      t.text :description

      # 0 slot, 1 table, 2 live, 3 instant, 4 crash, 5 other
      t.integer :category, null: false, default: 5
      # 0 active, 1 inactive, 2 hidden, 3 coming_soon
      t.integer :status, null: false, default: 3

      t.string :thumbnail_url
      t.bigint :min_bet_minor
      t.bigint :max_bet_minor
      t.json :supported_currencies, null: false, default: []
      t.json :metadata, null: false, default: {}
      t.datetime :released_at

      t.timestamps
    end

    add_index :games, %i[game_provider_id slug], unique: true
    add_index :games, :status
    add_index :games, :category
  end
end
