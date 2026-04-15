FactoryBot.define do
  factory :daily_price do
    association :tenant
    association :created_by, factory: :user
    mineral_type { "oro" }
    price_date { Date.current }
    unit_price_cop { 320_000.00 }
    state { "pending" }
    notes { nil }
    rejection_reason { nil }
    approved_at { nil }
    rejected_at { nil }
    reviewed_by { nil }
    metadata { {} }

    trait :approved do
      state { "approved" }
      approved_at { Time.current }
      reviewed_by { association :user }
    end

    trait :rejected do
      state { "rejected" }
      rejected_at { Time.current }
      rejection_reason { "Out of market range" }
      reviewed_by { association :user }
    end
  end
end
