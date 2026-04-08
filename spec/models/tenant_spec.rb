require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    it "requires a name" do
      tenant = build(:tenant, name: nil)

      expect(tenant).not_to be_valid
      expect(tenant.errors[:name]).to include("can't be blank")
    end

    it "normalizes the slug from the name when missing" do
      tenant = create(:tenant, slug: nil, name: "My Workspace")

      expect(tenant.slug).to eq("my-workspace")
    end
  end

  describe "#soft_delete!" do
    it "archives and marks tenant as deleted" do
      tenant = create(:tenant, status: "active", deleted_at: nil)

      tenant.soft_delete!

      expect(tenant.deleted_at).to be_present
      expect(tenant.status).to eq("archived")
    end
  end
end
