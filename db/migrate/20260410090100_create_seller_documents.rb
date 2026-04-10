class CreateSellerDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_documents do |t|
      t.references :seller, null: false, foreign_key: { on_delete: :cascade }
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :status, null: false, default: "uploaded"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :seller_documents, [ :seller_id, :kind ], name: "idx_seller_documents_seller_kind"
  end
end
