class CreateIdempotencyRecords < ActiveRecord::Migration[8.1]
  def change
    # Generic idempotency guard for non-financial side-effectful operations
    # (e.g. provider callbacks, admin actions). Financial idempotency is
    # enforced by the unique index on transactions.idempotency_key.
    create_table :idempotency_records do |t|
      t.string :scope, null: false
      t.string :key, null: false
      t.string :request_fingerprint
      # 0 in_progress, 1 completed, 2 failed
      t.integer :status, null: false, default: 0
      t.integer :response_status
      t.json :response_body, null: false, default: {}
      t.datetime :locked_at
      t.datetime :completed_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :idempotency_records, %i[scope key], unique: true
    add_index :idempotency_records, :expires_at
  end
end
