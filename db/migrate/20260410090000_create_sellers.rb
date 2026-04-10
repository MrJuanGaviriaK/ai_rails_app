class CreateSellers < ActiveRecord::Migration[8.1]
  def change
    create_table :sellers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :identification_type, null: false
      t.string :identification_number, null: false
      t.string :seller_type, null: false
      t.string :department, null: false
      t.string :city, null: false
      t.string :address, null: false
      t.string :phone
      t.string :email

      t.string :status, null: false, default: "pending"
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :sellers, [ :tenant_id, :identification_type, :identification_number ], unique: true,
      name: "idx_sellers_tenant_identification_unique"
    add_index :sellers, [ :tenant_id, :status ], name: "idx_sellers_tenant_status"
  end
end
