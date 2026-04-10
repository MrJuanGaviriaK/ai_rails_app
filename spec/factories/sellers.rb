FactoryBot.define do
  factory :seller do
    association :tenant
    association :created_by, factory: :user
    first_name { "Ana" }
    last_name { "Perez" }
    identification_type { "cc" }
    sequence(:identification_number) { |n| "#{1_000_000 + n}" }
    seller_type { "subsistence_miner" }
    department { "Antioquia" }
    city { "Medellin" }
    address { "Calle 10 # 20-30" }
    phone { "3000000000" }
    email { "seller@example.com" }
    status { "pending" }
    metadata { {} }
  end
end
