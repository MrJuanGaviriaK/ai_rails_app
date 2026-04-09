require "rails_helper"

RSpec.describe BuyerProfile, type: :model do
  describe "associations" do
    it "belongs to user" do
      buyer_profile = build(:buyer_profile)

      expect(buyer_profile.user).to be_present
    end

    it "belongs to purchasing location" do
      buyer_profile = build(:buyer_profile)

      expect(buyer_profile.purchasing_location).to be_present
    end
  end

  describe "validations" do
    it "enforces unique user" do
      user = create(:user)
      location = create(:purchasing_location)
      create(:buyer_profile, user: user, purchasing_location: location)

      duplicate = build(:buyer_profile, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include(I18n.t("errors.messages.taken"))
    end

    it "rejects archived purchasing locations" do
      location = create(:purchasing_location, deleted_at: Time.current)
      buyer_profile = build(:buyer_profile, purchasing_location: location)

      expect(buyer_profile).not_to be_valid
      expect(buyer_profile.errors[:purchasing_location]).to be_present
    end

    it "rejects inactive purchasing locations" do
      location = create(:purchasing_location, active: false)
      buyer_profile = build(:buyer_profile, purchasing_location: location)

      expect(buyer_profile).not_to be_valid
      expect(buyer_profile.errors[:purchasing_location]).to be_present
    end
  end
end
