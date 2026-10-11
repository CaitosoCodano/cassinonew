class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :description
      t.json :permissions, null: false, default: []
      t.boolean :system, null: false, default: false
      t.timestamps
    end

    add_index :roles, :name, unique: true
  end
end
