FactoryBot.define do
  factory :integration do
    association :tenant
    provider { "dropbox_sign" }
    name { "Dropbox Main" }
    status { "inactive" }
    priority { 0 }
    capabilities { [ "e_signature" ] }
    credentials { { "api_key" => "test_api_key_123", "client_id" => "client_id_123" } }
    provider_config { {} }
    settings { { "test_mode" => true } }
  end
end
