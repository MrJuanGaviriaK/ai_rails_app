# frozen_string_literal: true

class CreateESignatureTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :e_signature_templates do |t|
      t.boolean :active, default: true, null: false
      t.jsonb :custom_fields, default: [], null: false
      t.references :integration, null: false, foreign_key: true
      t.datetime :last_synced_at
      t.text :message
      t.jsonb :metadata, default: {}, null: false
      t.string :provider_template_id, null: false
      t.jsonb :signer_roles, default: [], null: false
      t.references :tenant, null: false, foreign_key: true
      t.string :title, null: false

      t.timestamps
    end

    add_index :e_signature_templates, [ :integration_id, :provider_template_id ], unique: true, name: :idx_esig_templates_integration_provider
    add_index :e_signature_templates, [ :tenant_id, :active ]
  end
end
