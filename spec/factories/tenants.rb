FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:slug) { |n| "tenant-#{n}" }
    status { "active" }
    settings { {} }
    deleted_at { nil }
  end
end
