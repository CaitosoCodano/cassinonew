class CreateFeatureFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flags do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.string :description
      t.integer :rollout_percentage, null: false, default: 100
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flags, :key, unique: true
  end
end
