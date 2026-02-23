# This file should ensure the existence of records required to run the application in every environment.
# The code here should be idempotent so that it can be executed at any point in every environment.
# Run with: bin/rails db:seed

# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------
%w[admin normal_user client].each do |role_name|
  Role.find_or_create_by!(name: role_name)
end

puts "Seed complete — roles: #{Role.pluck(:name).join(", ")}"

# ---------------------------------------------------------------------------
# Development test user
# ---------------------------------------------------------------------------
if Rails.env.development? || Rails.env.test?
  test_user = User.find_or_create_by!(email: "test@example.com") do |user|
    user.name     = "Test User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  test_user.add_role(:admin) unless test_user.has_role?(:admin)

  puts "Seed complete — test user: test@example.com / password123 (role: admin)"
end
