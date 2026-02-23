FactoryBot.define do
  factory :role do
    name { "normal_user" }

    trait :admin do
      name { "admin" }
    end

    trait :normal_user do
      name { "normal_user" }
    end

    trait :client do
      name { "client" }
    end
  end
end
