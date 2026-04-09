require "rails_helper"

RSpec.describe "Api::V1::ESignatureTemplates", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) do
    create(:user).tap { |user| user.add_role(:admin, tenant) }
  end
  let(:integration) { create(:integration, tenant: tenant) }

  before do
    sign_in_as(admin)
  end

  describe "POST /api/v1/e_signature_templates" do
    it "creates template linked to integration and tenant" do
      expect do
        post api_v1_e_signature_templates_path, params: {
          tenant: tenant.slug,
          e_signature_template: {
            integration_id: integration.id,
            title: "Offer Letter",
            message: "Please sign",
            signer_roles: [ { name: "client", order: 0 } ],
            metadata: { category: "hr" }
          }
        }
      end.to change(ESignatureTemplate, :count).by(1)

      expect(response).to have_http_status(:created)
      template = ESignatureTemplate.last
      expect(template.tenant_id).to eq(tenant.id)
      expect(template.integration_id).to eq(integration.id)
      expect(template.provider_template_id).to be_present
    end
  end

  describe "GET /api/v1/e_signature_templates" do
    it "returns templates scoped to integration" do
      matching = create(:e_signature_template, integration: integration, tenant: tenant, title: "A")
      _other = create(:e_signature_template, integration: create(:integration, tenant: tenant), tenant: tenant, title: "B")

      get api_v1_e_signature_templates_path, params: { tenant: tenant.slug, integration_id: integration.id }

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      ids = parsed.fetch("templates").map { |item| item.fetch("id") }
      expect(ids).to contain_exactly(matching.id)
    end
  end

  describe "PATCH /api/v1/e_signature_templates/:id" do
    it "updates template title" do
      template = create(:e_signature_template, integration: integration, tenant: tenant, title: "Old")

      patch api_v1_e_signature_template_path(template), params: {
        tenant: tenant.slug,
        e_signature_template: { title: "New" }
      }

      expect(response).to have_http_status(:ok)
      expect(template.reload.title).to eq("New")
    end
  end

  describe "DELETE /api/v1/e_signature_templates/:id" do
    it "deletes template" do
      template = create(:e_signature_template, integration: integration, tenant: tenant)

      expect do
        delete api_v1_e_signature_template_path(template), params: { tenant: tenant.slug }
      end.to change(ESignatureTemplate, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/v1/e_signature_templates/sync" do
    it "returns synced template payload for immediate UI refresh" do
      provider_templates = [
        {
          provider_template_id: "tpl_remote_123",
          title: "NDA",
          message: "Please sign",
          signer_roles: [ { "name" => "client", "order" => 0 } ],
          custom_fields: [ { "name" => "full_name", "type" => "text" } ],
          metadata: { "source" => "dropbox_sign_sync" },
          active: true,
          last_synced_at: Time.current
        }
      ]

      client = instance_double(Integrations::DropboxSignClient, list_templates: provider_templates)
      allow(Integrations::DropboxSignClient).to receive(:new).with(integration).and_return(client)

      post sync_api_v1_e_signature_templates_path, params: {
        tenant: tenant.slug,
        integration_id: integration.id
      }

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)

      # NOTE: This expectation is intentionally failing until sync endpoint
      # returns hydrated template payload for the frontend.
      expect(parsed.fetch("templates").size).to eq(1)
    end
  end
end
