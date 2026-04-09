# frozen_string_literal: true

class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.string :capabilities, array: true, default: [], null: false
      t.jsonb :credentials, default: {}, null: false
      t.datetime :last_connected_at
      t.string :last_error_message
      t.string :name, null: false
      t.integer :priority, default: 0, null: false
      t.string :provider, null: false
      t.jsonb :provider_config, default: {}, null: false
      t.jsonb :settings, default: {}, null: false
      t.string :status, default: "inactive", null: false
      t.references :tenant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :integrations, :capabilities, using: :gin
    add_index :integrations, :status
    add_index :integrations, [ :tenant_id, :provider ]
  end
end
