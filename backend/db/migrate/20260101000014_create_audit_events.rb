class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # Append-only administrative / financial audit trail.
    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users }

      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.json :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :audit_events, %i[auditable_type auditable_id]
    add_index :audit_events, :action
    add_index :audit_events, :created_at
  end
end
