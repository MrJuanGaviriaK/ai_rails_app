FactoryBot.define do
  factory :e_signature_template do
    association :integration
    tenant { integration.tenant }
    sequence(:title) { |n| "Template #{n}" }
    sequence(:provider_template_id) { |n| "tpl_#{n}" }
    message { "Please sign this document" }
    signer_roles { [ { "name" => "candidate", "order" => 0 } ] }
    custom_fields { [] }
    metadata { {} }
    active { true }
  end
end
