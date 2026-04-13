require "rails_helper"

RSpec.describe StoreMineralPurchaseSignedDocumentJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "stores signed document and clears failure reason" do
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
        provider_signature_request_id: "req_signed_1",
        status: "signed",
        failure_reason: "Files are still being processed. Please try again later."
      )

      client = instance_double(Integrations::DropboxSignClient)
      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:download_signature_request_files).with(signature_request_id: "req_signed_1").and_return("%PDF-1.7 fake")

      described_class.perform_now(request.id)

      expect(request.reload.failure_reason).to be_nil
      expect(purchase.reload.signed_documents).to be_attached
    end

    it "re-enqueues when provider files are still processing" do
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
        provider_signature_request_id: "req_signed_2",
        status: "signed"
      )

      client = instance_double(Integrations::DropboxSignClient)
      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)
      allow(client).to receive(:download_signature_request_files)
        .with(signature_request_id: "req_signed_2")
        .and_raise(Integrations::DropboxSignClient::Error, "Files are still being processed. Please try again later.")

      clear_enqueued_jobs

      expect do
        described_class.perform_now(request.id)
      end.to have_enqueued_job(StoreMineralPurchaseSignedDocumentJob).with(request.id, 2)

      expect(request.reload.failure_reason).to include("Files are still being processed")
    end
  end
end
