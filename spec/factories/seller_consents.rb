FactoryBot.define do
  factory :seller_consent, parent: :e_signature_request, class: "ESignatureRequest" do
    transient do
      seller { nil }
    end

    after(:build) do |record, evaluator|
      next if evaluator.seller.blank?

      record.requestable = evaluator.seller
      record.tenant ||= evaluator.seller.tenant
    end
  end
end
