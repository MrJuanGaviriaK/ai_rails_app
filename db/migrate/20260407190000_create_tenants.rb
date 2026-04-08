class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name
      t.string :slug, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :settings, null: false, default: {}
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :tenants, :slug, unique: true
    add_index :tenants, :status
    add_index :tenants, :deleted_at
  end
end
