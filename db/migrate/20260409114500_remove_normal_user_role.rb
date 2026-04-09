class RemoveNormalUserRole < ActiveRecord::Migration[8.0]
  def up
    role_ids = select_values("SELECT id FROM roles WHERE name = 'normal_user'")
    return if role_ids.empty?

    execute("DELETE FROM users_roles WHERE role_id IN (#{role_ids.join(",")})")
    execute("DELETE FROM roles WHERE name = 'normal_user'")
  end

  def down
    execute <<~SQL
      INSERT INTO roles (name, resource_type, resource_id, created_at, updated_at)
      SELECT 'normal_user', NULL, NULL, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1
        FROM roles
        WHERE name = 'normal_user' AND resource_type IS NULL AND resource_id IS NULL
      )
    SQL
  end
end
