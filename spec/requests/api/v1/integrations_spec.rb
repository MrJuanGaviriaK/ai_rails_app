require "rails_helper"

RSpec.describe "Api::V1::Integrations", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) do
    create(:user).tap { |user| user.add_role(:admin, tenant) }
  end

  before do
    sign_in_as(admin)
  end

  describe "GET /api/v1/integrations" do
    it "returns integrations scoped to current tenant" do
      create(:integration, tenant: tenant, name: "Tenant Integration")
      create(:integration, tenant: create(:tenant), name: "Other Integration")

      get api_v1_integrations_path, params: { tenant: tenant.slug }

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      names = parsed.fetch("integrations").map { |item| item.fetch("name") }
      expect(names).to contain_exactly("Tenant Integration")
    end
  end

  describe "POST /api/v1/integrations" do
    it "creates a dropbox integration" do
      expect do
        post api_v1_integrations_path, params: {
          tenant: tenant.slug,
          integration: {
            provider: "dropbox_sign",
            name: "Dropbox Prod",
            priority: 1,
            credentials: { api_key: "k-1", client_id: "c-1" },
            settings: { test_mode: true }
          }
        }
      end.to change(Integration, :count).by(1)

      expect(response).to have_http_status(:created)
      integration = Integration.last
      expect(integration.tenant_id).to eq(tenant.id)
      expect(integration.capabilities).to eq([ "e_signature" ])
    end
  end

  describe "PATCH /api/v1/integrations/:id" do
    it "updates integration status" do
      integration = create(:integration, tenant: tenant, status: "inactive")

      patch api_v1_integration_path(integration), params: {
        tenant: tenant.slug,
        integration: { status: "active" }
      }

      expect(response).to have_http_status(:ok)
      expect(integration.reload.status).to eq("active")
    end
  end

  describe "DELETE /api/v1/integrations/:id" do
    it "deletes integration" do
      integration = create(:integration, tenant: tenant)

      expect do
        delete api_v1_integration_path(integration), params: { tenant: tenant.slug }
      end.to change(Integration, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
