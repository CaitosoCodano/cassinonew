class CreateProviderEvents < ActiveRecord::Migration[8.1]
  def change
    # Inbound events / callbacks received from game providers. Persisting every
    # event (including rejected and duplicate ones) forms the provider audit
    # trail and protects against replay (external_id is unique).
    create_table :provider_events do |t|
      t.references :game_provider, foreign_key: true
      t.references :game_session, foreign_key: true

      t.string :event_type, null: false
      t.string :external_id, null: false
      t.json :payload, null: false, default: {}

      t.boolean :signature_valid, null: false, default: false
      # 0 received, 1 processed, 2 rejected, 3 duplicate
      t.integer :processing_status, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :provider_events, :external_id, unique: true
    add_index :provider_events, :processing_status
  end
end
