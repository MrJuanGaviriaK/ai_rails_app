require "rails_helper"

RSpec.describe Integrations::DropboxSign::WebhookService do
  describe ".process" do
    it "completes mineral purchase when signature is signed" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      template = create(:e_signature_template, tenant:, integration:, title: "seller_contract_accounts_for_participation_v1")
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_pending")
      request = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: template,
        provider_signature_request_id: "req_abc_123",
        status: "awaiting_signature"
      )

      event_data = {
        "signature_request" => {
          "signature_request_id" => "req_abc_123",
          "signatures" => [ { "status_code" => "signed", "signed_ip" => "127.0.0.1", "user_agent" => "RSpec" } ]
        }
      }

      client = instance_double(Integrations::DropboxSignClient)
      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:download_signature_request_files).with(signature_request_id: "req_abc_123").and_return("%PDF-1.7 fake")

      described_class.process(
        integration:,
        event_type: "signature_request_all_signed",
        event_data:
      )

      expect(request.reload.status).to eq("signed")
      expect(purchase.reload.status).to eq("completed")
      expect(purchase.signed_documents).to be_attached
    end

    it "marks mineral purchase as signature_failed for declined events" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      template = create(:e_signature_template, tenant:, integration:, title: "seller_contract_accounts_for_participation_v1")
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_pending")
      request = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: template,
        provider_signature_request_id: "req_declined_1",
        status: "awaiting_signature"
      )

      described_class.process(
        integration:,
        event_type: "signature_request_declined",
        event_data: { "signature_request" => { "signature_request_id" => "req_declined_1" } }
      )

      expect(request.reload.status).to eq("declined")
      expect(purchase.reload.status).to eq("signature_failed")
    end

    it "retries document download when request is already signed" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      template = create(:e_signature_template, tenant:, integration:, title: "seller_contract_accounts_for_participation_v1")
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_pending")
      request = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: template,
        provider_signature_request_id: "req_retry_1",
        status: "signed",
        failure_reason: "Files are still being processed. Please try again later."
      )

      event_data = {
        "signature_request" => {
          "signature_request_id" => "req_retry_1",
          "signatures" => [ { "status_code" => "signed" } ]
        }
      }

      client = instance_double(Integrations::DropboxSignClient)
      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:download_signature_request_files).with(signature_request_id: "req_retry_1").and_return("%PDF-1.7 fake")

      described_class.process(
        integration:,
        event_type: "signature_request_all_signed",
        event_data:
      )

      expect(request.reload.failure_reason).to be_nil
      expect(purchase.reload.status).to eq("completed")
      expect(purchase.signed_documents).to be_attached
    end
  end
end
