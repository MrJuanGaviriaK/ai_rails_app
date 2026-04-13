require "rails_helper"

RSpec.describe MineralPurchase, type: :model do
  describe "validations" do
    it "requires approved seller" do
      tenant = create(:tenant)
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "pending")

      purchase = described_class.new(
        tenant:,
        buyer:,
        seller:,
        mineral_type: "gold",
        fine_grams: 1.0,
        total_price_cop: 100.0
      )

      expect(purchase).not_to be_valid
      expect(purchase.errors[:seller]).to be_present
    end

    it "rounds numeric values to two decimals" do
      tenant = create(:tenant)
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")

      purchase = described_class.create!(
        tenant:,
        buyer:,
        seller:,
        mineral_type: "gold",
        fine_grams: 1.235,
        total_price_cop: 100.239
      )

      expect(purchase.fine_grams.to_s("F")).to eq("1.24")
      expect(purchase.total_price_cop.to_s("F")).to eq("100.24")
    end
  end
end
