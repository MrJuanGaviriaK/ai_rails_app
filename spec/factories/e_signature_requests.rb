FactoryBot.define do
  factory :e_signature_request do
    association :requestable, factory: :seller
    tenant { requestable.tenant }
    integration { create(:integration, tenant:) }
    e_signature_template { create(:e_signature_template, tenant:, integration:) }
    initiated_by { requestable.created_by }
    provider { "dropbox_sign" }
    status { "draft" }
    raw_provider_payload { {} }
  end
end
