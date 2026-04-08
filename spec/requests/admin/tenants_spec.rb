require "rails_helper"

RSpec.describe "Admin::Tenants", type: :request do
  describe "GET /admin/tenants" do
    it "redirects unauthenticated users to sign in" do
      get admin_tenants_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks non-superadmin users" do
      user = create(:user)
      sign_in_as(user)

      get admin_tenants_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "allows superadmin users" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      get admin_tenants_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "tenant lifecycle" do
    let(:superadmin) { create(:user, :superadmin) }

    before { sign_in_as(superadmin) }

    it "creates a tenant" do
      expect do
        post admin_tenants_path, params: {
          tenant: {
            name: "Acme",
            slug: "acme",
            status: "active",
            settings_json: "{\"timezone\":\"UTC\"}"
          }
        }
      end.to change(Tenant, :count).by(1)

      tenant = Tenant.last
      expect(tenant.settings).to eq("timezone" => "UTC")
      expect(response).to redirect_to(admin_tenants_path)
    end

    it "updates a tenant" do
      tenant = create(:tenant, name: "Old name")

      patch admin_tenant_path(tenant), params: {
        tenant: {
          name: "New name",
          slug: tenant.slug,
          status: "suspended",
          settings_json: "{\"mode\":\"readonly\"}"
        }
      }

      expect(response).to redirect_to(admin_tenants_path)
      expect(tenant.reload.name).to eq("New name")
      expect(tenant.status).to eq("suspended")
      expect(tenant.settings).to eq("mode" => "readonly")
    end

    it "soft deletes a tenant" do
      tenant = create(:tenant)

      delete admin_tenant_path(tenant)

      expect(response).to redirect_to(admin_tenants_path)
      expect(tenant.reload.deleted_at).to be_present
      expect(tenant.status).to eq("archived")
    end
  end
end
