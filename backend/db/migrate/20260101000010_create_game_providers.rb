class CreateGameProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :game_providers do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description

      # 0 active, 1 inactive, 2 maintenance, 3 error
      t.integer :status, null: false, default: 1

      # Fully-qualified constant of the integration adapter (must be registered
      # in Games::ProviderRegistry -- never eval'd or auto-required).
      t.string :adapter_class
      t.string :integration_version
      t.json :capabilities, null: false, default: {}
      t.json :config, null: false, default: {}

      # 0 unknown, 1 healthy, 2 degraded, 3 down
      t.integer :health_status, null: false, default: 0
      t.datetime :last_health_check_at
      t.text :last_health_error

      t.timestamps
    end

    add_index :game_providers, :slug, unique: true
    add_index :game_providers, :status
  end
end
