class CreateSellerConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_consents do |t|
      t.references :seller, null: false, foreign_key: { on_delete: :cascade }
      t.references :e_signature_template, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_signature_request_id
      t.string :provider_signature_id
      t.string :status, null: false, default: "draft"
      t.datetime :signed_at
      t.string :signed_ip
      t.string :user_agent
      t.jsonb :raw_provider_payload, null: false, default: {}

      t.timestamps
    end

    add_index :seller_consents, [ :seller_id, :status ], name: "idx_seller_consents_seller_status"
  end
end
