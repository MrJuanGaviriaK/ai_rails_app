FactoryBot.define do
  factory :purchasing_location do
    association :tenant
    sequence(:name) { |n| "Purchasing Location #{n}" }
    department { "Antioquia" }
    city { "Medellín" }
    sequence(:address) { |n| "Calle #{n} # 10-20" }
    active { true }
    notes { nil }
    deleted_at { nil }
  end
end
