class CreatePurchasingLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :purchasing_locations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :department, null: false
      t.string :city, null: false
      t.string :address, null: false
      t.boolean :active, null: false, default: true
      t.text :notes
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :purchasing_locations, :deleted_at
    add_index :purchasing_locations, [ :tenant_id, :deleted_at ]
    add_index :purchasing_locations, [ :tenant_id, :department ]
  end
end
