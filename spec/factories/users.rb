FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Jane Doe" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }

    # --- Confirmable traits ------------------------------------------------
    trait :unconfirmed do
      confirmed_at         { nil }
      confirmation_sent_at { 1.hour.ago }
    end

    trait :confirmation_expired do
      confirmed_at         { nil }
      confirmation_sent_at { 4.days.ago }
    end

    # --- Role traits --------------------------------------------------------
    trait :admin do
      after(:create) { |user| user.add_role(:admin) }
    end

    trait :client do
      after(:create) { |user| user.add_role(:client) }
    end

    trait :superadmin do
      after(:create) { |user| user.add_role(:superadmin) }
    end

    trait :buyer do
      after(:create) do |user|
        tenant = create(:tenant)
        location = create(:purchasing_location, tenant: tenant)
        user.add_role(:buyer, tenant)
        create(:buyer_profile, user: user, purchasing_location: location)
      end
    end
  end
end
