class CreateBuyerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :buyer_profiles do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :purchasing_location, null: false, foreign_key: { on_delete: :restrict }
      t.references :created_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end
  end
end
