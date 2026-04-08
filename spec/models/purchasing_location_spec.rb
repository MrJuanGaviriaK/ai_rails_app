require "rails_helper"

RSpec.describe PurchasingLocation, type: :model do
  describe "validations" do
    it "requires required fields" do
      purchasing_location = build(:purchasing_location, name: nil, department: nil, city: nil, address: nil)

      expect(purchasing_location).not_to be_valid
      expect(purchasing_location.errors[:name]).to include(I18n.t("errors.messages.blank"))
      expect(purchasing_location.errors[:department]).to include(I18n.t("errors.messages.blank"))
      expect(purchasing_location.errors[:city]).to include(I18n.t("errors.messages.blank"))
      expect(purchasing_location.errors[:address]).to include(I18n.t("errors.messages.blank"))
    end

    it "validates department against the Colombian list" do
      purchasing_location = build(:purchasing_location, department: "Ontario")

      expect(purchasing_location).not_to be_valid
      expect(purchasing_location.errors[:department]).to be_present
    end
  end

  describe "#soft_delete!" do
    it "marks record as deleted" do
      purchasing_location = create(:purchasing_location, deleted_at: nil)

      purchasing_location.soft_delete!

      expect(purchasing_location.deleted_at).to be_present
    end
  end
end
