class CreateDailyPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_prices do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :mineral_type, null: false
      t.date :price_date, null: false
      t.decimal :unit_price_cop, precision: 14, scale: 2, null: false
      t.string :state, null: false, default: "pending"
      t.text :notes
      t.text :rejection_reason
      t.datetime :approved_at
      t.datetime :rejected_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :daily_prices,
      [ :tenant_id, :mineral_type, :price_date ],
      unique: true,
      where: "state = 'approved'",
      name: "idx_daily_prices_unique_approved_per_day"
    add_index :daily_prices, [ :tenant_id, :mineral_type, :price_date, :state ], name: "idx_daily_prices_resolver_lookup"
    add_index :daily_prices, [ :tenant_id, :price_date ], order: { price_date: :desc }, name: "idx_daily_prices_tenant_price_date_desc"
    add_index :daily_prices, [ :tenant_id, :state ], name: "idx_daily_prices_tenant_state"

    add_check_constraint :daily_prices, "unit_price_cop > 0", name: "chk_daily_prices_unit_price_positive"
    add_check_constraint :daily_prices, "state IN ('pending','approved','rejected')", name: "chk_daily_prices_state_valid"
    add_check_constraint :daily_prices, "state != 'approved' OR approved_at IS NOT NULL", name: "chk_daily_prices_approved_at_required"
    add_check_constraint :daily_prices, "state != 'rejected' OR rejected_at IS NOT NULL", name: "chk_daily_prices_rejected_at_required"
  end
end
