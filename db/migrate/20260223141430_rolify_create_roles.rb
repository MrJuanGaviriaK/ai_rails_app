class RolifyCreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.references :resource, polymorphic: true

      t.timestamps
    end

    create_table :users_roles, id: false do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
    end

    add_index :roles, [ :name, :resource_type, :resource_id ]
    add_index :users_roles, [ :user_id, :role_id ], unique: true
  end
end
