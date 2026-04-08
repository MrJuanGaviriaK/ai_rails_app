require "rails_helper"

RSpec.describe "Admin::TenantContexts", type: :request do
  describe "POST /admin/tenant_context/switch" do
    it "allows superadmin to switch active tenant" do
      superadmin = create(:user, :superadmin)
      first_tenant = create(:tenant, name: "Alpha")
      second_tenant = create(:tenant, name: "Beta")

      sign_in_as(superadmin)
      post admin_switch_tenant_context_path, params: { tenant_id: first_tenant.id }

      post admin_switch_tenant_context_path, params: { tenant_id: second_tenant.id }
      follow_redirect!

      expect(response.body).to include(I18n.t("dashboard.index.current_tenant"))
      expect(response.body).to include("Beta")
    end

    it "blocks non-superadmin users" do
      user = create(:user)
      tenant = create(:tenant)

      sign_in_as(user)
      post admin_switch_tenant_context_path, params: { tenant_id: tenant.id }

      expect(response).to redirect_to(dashboard_path)
    end

    it "rejects inactive tenants" do
      superadmin = create(:user, :superadmin)
      archived_tenant = create(:tenant, status: "archived")

      sign_in_as(superadmin)
      post admin_switch_tenant_context_path, params: { tenant_id: archived_tenant.id }

      expect(response).to redirect_to(dashboard_path)
    end
  end
end
