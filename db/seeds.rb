# This file should ensure the existence of records required to run the application in every environment.
# The code here should be idempotent so that it can be executed at any point in every environment.
# Run with: bin/rails db:seed

# Development test user — do NOT use this password in production
User.find_or_create_by!(email: "test@example.com") do |user|
  user.name     = "Test User"
  user.password = "password123"
  user.password_confirmation = "password123"
end

puts "Seed complete — test user: test@example.com / password123"
