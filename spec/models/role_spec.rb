require "rails_helper"

RSpec.describe Role, type: :model do
  describe "validations" do
    it "is valid with a name" do
      role = described_class.new(name: "admin")
      expect(role).to be_valid
    end
  end

  describe "associations" do
    it "can be associated with users" do
      role = create(:role, :admin)
      user = create(:user)
      user.add_role(:admin)
      expect(role.users).to include(user)
    end
  end
end
