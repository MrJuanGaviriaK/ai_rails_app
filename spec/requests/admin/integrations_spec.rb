require "rails_helper"

RSpec.describe "Admin::Integrations", type: :request do
  describe "GET /admin/integrations" do
    it "redirects unauthenticated users to sign in" do
      get admin_integrations_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks users without permissions" do
      user = create(:user)
      sign_in_as(user)

      get admin_integrations_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "allows superadmin users" do
      create(:tenant)
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      get admin_integrations_path

      expect(response).to have_http_status(:ok)
    end

    it "allows tenant admins" do
      admin = create(:user)
      tenant = create(:tenant)
      admin.add_role(:admin, tenant)

      sign_in_as(admin)
      get admin_integrations_path

      expect(response).to have_http_status(:ok)
    end
  end
end
