require "rails_helper"

RSpec.describe Sellers::Consent::StartEmbeddedSigning do
  describe ".call" do
    it "uses template signer role when creating embedded request" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:)
      template = create(
        :e_signature_template,
        tenant:,
        integration:,
        signer_roles: [ { "name" => "SELLER", "order" => 0 } ]
      )
      seller = create(:seller, tenant:)
      consent = create(:e_signature_request, requestable: seller, e_signature_template: template, status: "draft")
      actor = create(:user)

      client = instance_double(Integrations::DropboxSignClient)

      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:create_embedded_signature_request_with_template).and_return(
        {
          "signature_request" => {
            "signature_request_id" => "req_123",
            "signatures" => [ { "signature_id" => "sig_123" } ]
          }
        }
      )
      allow(client).to receive(:embedded_sign_url).with(signature_id: "sig_123").and_return(
        { "sign_url" => "https://app.hellosign.com/editor/embedded?token=abc" }
      )

      described_class.call(seller:, actor:)

      expect(client).to have_received(:create_embedded_signature_request_with_template).with(
        hash_including(signer_role: "SELLER")
      )
      expect(consent.reload.status).to eq("awaiting_signature")
    end

    it "maps uppercase template custom fields with seller data" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:)
      template = create(
        :e_signature_template,
        tenant:,
        integration:,
        signer_roles: [ { "name" => "SELLER", "order" => 0 } ],
        custom_fields: [
          { "name" => "SELLER_FULLNAME" },
          { "name" => "SELLER_IDENTIFICATION" }
        ]
      )
      seller = create(
        :seller,
        tenant:,
        first_name: "Ana",
        last_name: "García",
        identification_number: "CC-123.456"
      )
      create(:e_signature_request, requestable: seller, e_signature_template: template, status: "draft")
      actor = create(:user)

      client = instance_double(Integrations::DropboxSignClient)

      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:create_embedded_signature_request_with_template).and_return(
        {
          "signature_request" => {
            "signature_request_id" => "req_123",
            "signatures" => [ { "signature_id" => "sig_123" } ]
          }
        }
      )
      allow(client).to receive(:embedded_sign_url).with(signature_id: "sig_123").and_return(
        { "sign_url" => "https://app.hellosign.com/editor/embedded?token=abc" }
      )

      described_class.call(seller:, actor:)

      expect(client).to have_received(:create_embedded_signature_request_with_template).with(
        hash_including(
          custom_fields: [
            { name: "SELLER_FULLNAME", value: "Ana García" },
            { name: "SELLER_IDENTIFICATION", value: "CC123456" }
          ]
        )
      )
    end
  end
end
