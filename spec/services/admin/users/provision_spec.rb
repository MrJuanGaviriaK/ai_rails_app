require "rails_helper"

RSpec.describe Admin::Users::Provision do
  describe ".call" do
    let(:tenant) { create(:tenant) }
    let(:location) { create(:purchasing_location, tenant: tenant) }

    context "when actor is superadmin" do
      it "creates a buyer with buyer profile" do
        actor = create(:user, :superadmin)

        result = described_class.call(
          actor: actor,
          current_tenant: tenant,
          attributes: {
            name: "Buyer User",
            email: "buyer1@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "buyer",
            tenant_id: tenant.id,
            purchasing_location_id: location.id
          }
        )

        expect(result.success?).to be(true)
        expect(result.user).to be_persisted
        expect(result.user.has_role?(:buyer, tenant)).to be(true)
        expect(result.user.buyer_profile.purchasing_location).to eq(location)
      end

      it "creates a superadmin without tenant" do
        actor = create(:user, :superadmin)

        result = described_class.call(
          actor: actor,
          current_tenant: tenant,
          attributes: {
            name: "Root",
            email: "root@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "superadmin"
          }
        )

        expect(result.success?).to be(true)
        expect(result.user.has_role?(:superadmin)).to be(true)
        expect(result.user.roles.count).to eq(1)
      end
    end

    context "when actor is tenant admin" do
      it "creates only allowed roles inside current tenant" do
        actor = create(:user)
        actor.add_role(:admin, tenant)

        result = described_class.call(
          actor: actor,
          current_tenant: tenant,
          attributes: {
            name: "Client User",
            email: "client1@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "client",
            tenant_id: tenant.id
          }
        )

        expect(result.success?).to be(true)
        expect(result.user.has_role?(:client, tenant)).to be(true)
      end

      it "rejects superadmin role" do
        actor = create(:user)
        actor.add_role(:admin, tenant)

        result = described_class.call(
          actor: actor,
          current_tenant: tenant,
          attributes: {
            name: "Not Allowed",
            email: "not-allowed@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "superadmin"
          }
        )

        expect(result.success?).to be(false)
        expect(result.user).not_to be_persisted
      end

      it "allows compliance_officer role inside current tenant" do
        actor = create(:user)
        actor.add_role(:admin, tenant)

        result = described_class.call(
          actor: actor,
          current_tenant: tenant,
          attributes: {
            name: "Compliance User",
            email: "compliance1@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "compliance_officer",
            tenant_id: tenant.id
          }
        )

        expect(result.success?).to be(true)
        expect(result.user.has_role?(:compliance_officer, tenant)).to be(true)
      end
    end

    it "fails for buyer without purchasing location" do
      actor = create(:user, :superadmin)

      result = described_class.call(
        actor: actor,
        current_tenant: tenant,
        attributes: {
          name: "Buyer Missing Location",
          email: "buyer-missing-location@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "buyer",
          tenant_id: tenant.id
        }
      )

      expect(result.success?).to be(false)
      expect(result.user).not_to be_persisted
      expect(result.user.errors.full_messages.join(" ")).to include(I18n.t("admin.users.errors.purchasing_location_required"))
    end

    it "fails for buyer with location from another tenant" do
      actor = create(:user, :superadmin)
      other_tenant = create(:tenant)
      other_location = create(:purchasing_location, tenant: other_tenant)

      result = described_class.call(
        actor: actor,
        current_tenant: tenant,
        attributes: {
          name: "Buyer Out Of Scope",
          email: "buyer-out-of-scope@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "buyer",
          tenant_id: tenant.id,
          purchasing_location_id: other_location.id
        }
      )

      expect(result.success?).to be(false)
      expect(result.user).not_to be_persisted
      expect(result.user.errors.full_messages.join(" ")).to include(I18n.t("admin.users.errors.purchasing_location_out_of_scope"))
    end

    it "does not create buyer profile for non-buyer roles" do
      actor = create(:user, :superadmin)

      result = described_class.call(
        actor: actor,
        current_tenant: tenant,
        attributes: {
          name: "Normal User",
          email: "normal-user@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "client",
          tenant_id: tenant.id,
          purchasing_location_id: location.id
        }
      )

      expect(result.success?).to be(true)
      expect(result.user.has_role?(:client, tenant)).to be(true)
      expect(result.user.buyer_profile).to be_nil
    end
  end
end
