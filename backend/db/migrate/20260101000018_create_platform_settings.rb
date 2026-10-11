class CreatePlatformSettings < ActiveRecord::Migration[8.1]
  def change
    # Operator-editable configuration (distinct from feature flags, which are
    # boolean switches). Values are JSON so the schema stays stable.
    create_table :platform_settings do |t|
      t.string :key, null: false
      t.json :value, null: false, default: {}
      t.string :category, null: false, default: "general"
      t.string :description
      t.boolean :editable, null: false, default: true

      t.timestamps
    end

    add_index :platform_settings, :key, unique: true
    add_index :platform_settings, :category
  end
end
