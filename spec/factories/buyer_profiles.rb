FactoryBot.define do
  factory :buyer_profile do
    association :user
    association :purchasing_location
    association :created_by, factory: :user
  end
end
