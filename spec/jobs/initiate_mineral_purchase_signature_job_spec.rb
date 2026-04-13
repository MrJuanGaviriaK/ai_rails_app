require "rails_helper"

RSpec.describe InitiateMineralPurchaseSignatureJob, type: :job do
  describe "#perform" do
    it "sends signature request and updates statuses" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      template = create(
        :e_signature_template,
        tenant:,
        integration:,
        title: "seller_contract_accounts_for_participation_v1",
        signer_roles: [ { "name" => "SELLER", "order" => 0 } ],
        custom_fields: [
          { "name" => "SELLER_FULLNAME" },
          { "name" => "SELLER_IDENTIFICATION" },
          { "name" => "SELLER_GRAMS" },
          { "name" => "SELLER_TOTAL_PRICE" }
        ]
      )
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved", email: "seller@example.com")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, fine_grams: 10.2, total_price_cop: 500.5)
      request = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: template,
        status: "draft"
      )

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

      described_class.perform_now(purchase.id)

      expect(request.reload.status).to eq("awaiting_signature")
      expect(request.provider_signature_request_id).to eq("req_123")
      expect(purchase.reload.status).to eq("signature_pending")
    end
  end
end
