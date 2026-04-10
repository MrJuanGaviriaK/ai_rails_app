require "rails_helper"

RSpec.describe "Webhooks::DropboxSign", type: :request do
  describe "POST /webhooks/dropbox_sign" do
    it "responds callback_test handshake" do
      post webhooks_dropbox_sign_path, params: {
        json: {
          event: {
            event_type: "callback_test"
          }
        }.to_json
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("Hello API Event Received")
    end

    it "processes signed events by resolving integration from e_signature_request" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      template = create(:e_signature_template, tenant:, integration:)
      seller = create(:seller, tenant:)
      create(
        :e_signature_request,
        requestable: seller,
        tenant:,
        integration:,
        e_signature_template: template,
        provider_signature_request_id: "req_abc_123"
      )

      payload = {
        event: { event_type: "signature_request_all_signed" },
        signature_request: { signature_request_id: "req_abc_123" }
      }

      expect(Integrations::DropboxSign::WebhookService).to receive(:process).with(
        integration:,
        event_type: "signature_request_all_signed",
        event_data: hash_including("signature_request" => hash_including("signature_request_id" => "req_abc_123"))
      )

      post webhooks_dropbox_sign_path, params: { json: payload.to_json }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("Hello API Event Received")
    end
  end
end
