require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  describe "GET /admin/users" do
    it "redirects unauthenticated users to sign in" do
      get admin_users_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks users without user-management permissions" do
      user = create(:user)
      sign_in_as(user)

      get admin_users_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "allows superadmin users" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      get admin_users_path

      expect(response).to have_http_status(:ok)
    end

    it "shows only tenant-scoped users for tenant admins" do
      tenant = create(:tenant)
      other_tenant = create(:tenant)
      admin = create(:user)
      scoped_user = create(:user)
      outsider_user = create(:user)

      admin.add_role(:admin, tenant)
      scoped_user.add_role(:client, tenant)
      outsider_user.add_role(:client, other_tenant)

      sign_in_as(admin)
      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(scoped_user.email)
      expect(response.body).not_to include(outsider_user.email)
    end
  end

  describe "GET /admin/users/new" do
    it "redirects unauthenticated users to sign in" do
      get new_admin_user_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks users without user-management permissions" do
      user = create(:user)
      sign_in_as(user)

      get new_admin_user_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "allows superadmin users" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      get new_admin_user_path

      expect(response).to have_http_status(:ok)
    end

    it "allows tenant admin users" do
      admin = create(:user)
      tenant = create(:tenant)
      admin.add_role(:admin, tenant)

      sign_in_as(admin)
      get new_admin_user_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/users" do
    let(:tenant) { create(:tenant) }
    let(:location) { create(:purchasing_location, tenant: tenant) }

    it "creates a buyer with valid tenant and location as superadmin" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      expect do
        post admin_users_path, params: {
          user: {
            name: "Buyer User",
            email: "buyer-request@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "buyer",
            tenant_id: tenant.id,
            purchasing_location_id: location.id
          }
        }
      end.to change(User, :count).by(1).and change(BuyerProfile, :count).by(1)

      created_user = User.find_by(email: "buyer-request@example.com")
      expect(created_user).to be_present
      expect(created_user.has_role?(:buyer, tenant)).to be(true)
      expect(created_user.buyer_profile.purchasing_location).to eq(location)
      expect(response).to redirect_to(admin_users_path)
    end

    it "fails when creating buyer without location" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      expect do
        post admin_users_path, params: {
          user: {
            name: "Buyer Missing Location",
            email: "buyer-missing-location-request@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "buyer",
            tenant_id: tenant.id
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.users.errors.purchasing_location_required"))
    end

    it "allows tenant admin to create admin role" do
      admin = create(:user)
      admin.add_role(:admin, tenant)

      sign_in_as(admin)

      expect {
        post admin_users_path, params: {
          user: {
            name: "Tenant Admin",
            email: "tenant-admin-created@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "admin",
            tenant_id: tenant.id
          }
        }
      }.to change(User, :count).by(1)

      created_user = User.find_by(email: "tenant-admin-created@example.com")
      expect(created_user).to be_present
      expect(created_user.has_role?(:admin, tenant)).to be(true)
      expect(response).to redirect_to(admin_users_path)
    end

    it "prevents buyer assignment to purchasing location from another tenant" do
      superadmin = create(:user, :superadmin)
      other_tenant = create(:tenant)
      other_location = create(:purchasing_location, tenant: other_tenant)
      sign_in_as(superadmin)

      expect do
        post admin_users_path, params: {
          user: {
            name: "Out Of Scope Buyer",
            email: "buyer-out-of-scope-request@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "buyer",
            tenant_id: tenant.id,
            purchasing_location_id: other_location.id
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.users.errors.purchasing_location_out_of_scope"))
    end
  end

  describe "DELETE /admin/users/:id" do
    it "archives a user for superadmin" do
      superadmin = create(:user, :superadmin)
      target_user = create(:user)

      sign_in_as(superadmin)

      expect {
        delete admin_user_path(target_user)
      }.to change { target_user.reload.deleted_at.present? }.from(false).to(true)

      expect(response).to redirect_to(admin_users_path)
    end

    it "archives a user in current tenant for tenant admin" do
      tenant = create(:tenant)
      admin = create(:user)
      target_user = create(:user)
      admin.add_role(:admin, tenant)
      target_user.add_role(:client, tenant)

      sign_in_as(admin)

      expect {
        delete admin_user_path(target_user)
      }.to change { target_user.reload.deleted_at.present? }.from(false).to(true)

      expect(response).to redirect_to(admin_users_path)
    end
  end

  describe "PATCH /admin/users/:id/restore" do
    it "restores an archived user" do
      superadmin = create(:user, :superadmin)
      target_user = create(:user)
      target_user.soft_delete!

      sign_in_as(superadmin)

      expect {
        patch restore_admin_user_path(target_user)
      }.to change { target_user.reload.deleted_at.present? }.from(true).to(false)

      expect(response).to redirect_to(admin_users_path(status: "archived"))
    end
  end

  describe "POST /users/sign_in" do
    it "prevents archived users from signing in" do
      user = create(:user)
      user.soft_delete!

      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }

      follow_redirect!

      expect(response.body).to include(I18n.t("devise.failure.archived"))
    end
  end
end
