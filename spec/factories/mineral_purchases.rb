FactoryBot.define do
  factory :mineral_purchase do
    seller { association :seller, status: "approved" }
    tenant { seller.tenant }
    association :buyer, factory: :user
    purchasing_location { nil }
    mineral_type { "gold" }
    fine_grams { 10.25 }
    total_price_cop { 250_000.50 }
    status { "created" }
    metadata { {} }

    after(:build) do |purchase|
      purchase.buyer.add_role(:buyer, purchase.tenant) unless purchase.buyer.buyer_for_tenant?(purchase.tenant)
    end
  end
end
