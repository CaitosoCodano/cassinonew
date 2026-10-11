class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.string :display_name
      t.string :first_name
      t.string :last_name
      t.date :date_of_birth
      t.string :country_code, limit: 2
      t.string :phone
      t.string :locale, null: false, default: "en"

      # 0 not_started, 1 pending, 2 verified, 3 rejected
      t.integer :identity_verification_status, null: false, default: 0
      t.datetime :identity_reviewed_at

      t.boolean :marketing_opt_in, null: false, default: false

      t.timestamps
    end
  end
end
