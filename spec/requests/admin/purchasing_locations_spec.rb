require "rails_helper"

RSpec.describe "Admin::PurchasingLocations", type: :request do
  describe "GET /admin/purchasing_locations" do
    it "redirects unauthenticated users to sign in" do
      get admin_purchasing_locations_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks users without admin permissions in current tenant" do
      user = create(:user)
      tenant = create(:tenant)
      user.add_role(:normal_user, tenant)

      sign_in_as(user)
      get admin_purchasing_locations_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "allows superadmin users" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      get admin_purchasing_locations_path

      expect(response).to have_http_status(:ok)
    end

    it "allows tenant admin users" do
      admin = create(:user)
      tenant = create(:tenant)
      admin.add_role(:admin, tenant)

      sign_in_as(admin)
      get admin_purchasing_locations_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "tenant scoping" do
    it "prevents tenant admin from accessing another tenant location" do
      admin = create(:user)
      tenant = create(:tenant)
      other_tenant = create(:tenant)
      admin.add_role(:admin, tenant)
      other_location = create(:purchasing_location, tenant: other_tenant)

      sign_in_as(admin)
      get admin_purchasing_location_path(other_location)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "lifecycle" do
    let(:tenant) { create(:tenant) }

    it "creates a purchasing location as superadmin" do
      superadmin = create(:user, :superadmin)
      sign_in_as(superadmin)

      expect do
        post admin_purchasing_locations_path, params: {
          purchasing_location: {
            tenant_id: tenant.id,
            name: "Punto Central",
            department: "Antioquia",
            city: "Medellín",
            address: "Calle 10 # 25-40",
            active: "1",
            notes: "Test notes"
          }
        }
      end.to change(PurchasingLocation, :count).by(1)

      purchasing_location = PurchasingLocation.last
      expect(purchasing_location.tenant).to eq(tenant)
      expect(response).to redirect_to(admin_purchasing_location_path(purchasing_location))
    end

    it "forces tenant admin records to current tenant" do
      admin = create(:user)
      admin_tenant = create(:tenant)
      other_tenant = create(:tenant)
      admin.add_role(:admin, admin_tenant)
      sign_in_as(admin)

      expect do
        post admin_purchasing_locations_path, params: {
          purchasing_location: {
            tenant_id: other_tenant.id,
            name: "Punto Admin",
            department: "Antioquia",
            city: "Medellín",
            address: "Carrera 45 # 12-34",
            active: "1"
          }
        }
      end.to change(PurchasingLocation, :count).by(1)

      expect(PurchasingLocation.last.tenant).to eq(admin_tenant)
    end

    it "updates a purchasing location" do
      superadmin = create(:user, :superadmin)
      purchasing_location = create(:purchasing_location, tenant: tenant, name: "Old name")

      sign_in_as(superadmin)
      patch admin_purchasing_location_path(purchasing_location), params: {
        purchasing_location: {
          tenant_id: tenant.id,
          name: "New name",
          department: "Cundinamarca",
          city: "Bogotá",
          address: "Carrera 7 # 20-10",
          active: "0"
        }
      }

      expect(response).to redirect_to(admin_purchasing_location_path(purchasing_location))
      expect(purchasing_location.reload.name).to eq("New name")
      expect(purchasing_location.department).to eq("Cundinamarca")
      expect(purchasing_location.active).to eq(false)
    end

    it "soft deletes a purchasing location" do
      superadmin = create(:user, :superadmin)
      purchasing_location = create(:purchasing_location, tenant: tenant)

      sign_in_as(superadmin)
      delete admin_purchasing_location_path(purchasing_location)

      expect(response).to redirect_to(admin_purchasing_locations_path)
      expect(purchasing_location.reload.deleted_at).to be_present
    end
  end
end
