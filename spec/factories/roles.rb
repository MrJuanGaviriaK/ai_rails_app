FactoryBot.define do
  factory :role do
    name { "client" }

    trait :admin do
      name { "admin" }
    end

    trait :client do
      name { "client" }
    end

    trait :buyer do
      name { "buyer" }
    end
  end
end
