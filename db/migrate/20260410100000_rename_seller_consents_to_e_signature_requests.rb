class RenameSellerConsentsToESignatureRequests < ActiveRecord::Migration[8.1]
  def up
    rename_table :seller_consents, :e_signature_requests
    rename_column :e_signature_requests, :seller_id, :requestable_id

    add_column :e_signature_requests, :requestable_type, :string, default: "Seller", null: false
    add_reference :e_signature_requests, :tenant, foreign_key: true
    add_reference :e_signature_requests, :integration, foreign_key: true
    add_reference :e_signature_requests, :initiated_by, foreign_key: { to_table: :users }
    add_column :e_signature_requests, :sent_at, :datetime
    add_column :e_signature_requests, :completed_at, :datetime
    add_column :e_signature_requests, :failed_at, :datetime
    add_column :e_signature_requests, :failure_reason, :text

    execute <<~SQL.squish
      UPDATE e_signature_requests requests
      SET tenant_id = templates.tenant_id,
          integration_id = templates.integration_id
      FROM e_signature_templates templates
      WHERE requests.e_signature_template_id = templates.id
    SQL

    change_column_null :e_signature_requests, :tenant_id, false
    change_column_null :e_signature_requests, :integration_id, false

    remove_index :e_signature_requests, name: "idx_seller_consents_seller_status", if_exists: true
    add_index :e_signature_requests, [ :requestable_type, :requestable_id, :status ], name: "idx_e_signature_requests_requestable_status"
    add_index :e_signature_requests, [ :tenant_id, :status ], name: "idx_e_signature_requests_tenant_status"
    add_index :e_signature_requests, [ :provider, :provider_signature_request_id ], name: "idx_e_signature_requests_provider_request"
  end

  def down
    remove_index :e_signature_requests, name: "idx_e_signature_requests_provider_request", if_exists: true
    remove_index :e_signature_requests, name: "idx_e_signature_requests_tenant_status", if_exists: true
    remove_index :e_signature_requests, name: "idx_e_signature_requests_requestable_status", if_exists: true

    remove_column :e_signature_requests, :failure_reason
    remove_column :e_signature_requests, :failed_at
    remove_column :e_signature_requests, :completed_at
    remove_column :e_signature_requests, :sent_at
    remove_reference :e_signature_requests, :initiated_by, foreign_key: { to_table: :users }
    remove_reference :e_signature_requests, :integration, foreign_key: true
    remove_reference :e_signature_requests, :tenant, foreign_key: true
    remove_column :e_signature_requests, :requestable_type

    rename_column :e_signature_requests, :requestable_id, :seller_id
    rename_table :e_signature_requests, :seller_consents

    add_index :seller_consents, [ :seller_id, :status ], name: "idx_seller_consents_seller_status"
  end
end
