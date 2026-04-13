class CreateMineralPurchasesAndSignatureConstraints < ActiveRecord::Migration[8.1]
  def change
    create_table :mineral_purchases do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.references :seller, null: false, foreign_key: true
      t.references :purchasing_location, null: true, foreign_key: { on_delete: :nullify }
      t.string :mineral_type, null: false
      t.decimal :fine_grams, precision: 12, scale: 2, null: false
      t.decimal :total_price_cop, precision: 14, scale: 2, null: false
      t.string :status, null: false, default: "created"
      t.datetime :completed_at
      t.datetime :canceled_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :mineral_purchases, [ :tenant_id, :status ], name: "idx_mineral_purchases_tenant_status"
    add_index :mineral_purchases, [ :tenant_id, :buyer_id ], name: "idx_mineral_purchases_tenant_buyer"
    add_index :mineral_purchases, [ :tenant_id, :seller_id ], name: "idx_mineral_purchases_tenant_seller"

    add_check_constraint :mineral_purchases, "fine_grams > 0", name: "chk_mineral_purchases_fine_grams_positive"
    add_check_constraint :mineral_purchases, "total_price_cop > 0", name: "chk_mineral_purchases_total_price_positive"

    remove_foreign_key :e_signature_requests, column: :requestable_id

    remove_index :e_signature_requests, name: "idx_e_signature_requests_provider_request", if_exists: true
    add_index :e_signature_requests,
      [ :provider, :provider_signature_request_id ],
      unique: true,
      where: "provider_signature_request_id IS NOT NULL",
      name: "idx_e_signature_requests_provider_request"

    add_index :e_signature_requests,
      [ :requestable_type, :requestable_id ],
      unique: true,
      where: "requestable_type = 'MineralPurchase'",
      name: "idx_e_signature_requests_mineral_purchase_unique"
  end
end
