require "rails_helper"

RSpec.describe DailyPrices::Resolver do
  describe ".call" do
    it "returns approved daily price for tenant/mineral/date" do
      tenant = create(:tenant)
      approved = create(:daily_price, :approved, tenant:, mineral_type: "oro", price_date: Date.current)

      result = described_class.call(tenant:, mineral_type: "oro", on_date: Date.current)

      expect(result.success?).to be(true)
      expect(result.daily_price).to eq(approved)
      expect(result.error).to be_nil
    end

    it "ignores non-approved records" do
      tenant = create(:tenant)
      create(:daily_price, tenant:, mineral_type: "oro", price_date: Date.current, state: "pending")
      create(:daily_price, :rejected, tenant:, mineral_type: "oro", price_date: Date.current)

      result = described_class.call(tenant:, mineral_type: "oro", on_date: Date.current)

      expect(result.success?).to be(false)
      expect(result.daily_price).to be_nil
      expect(result.error).to eq(:daily_price_not_approved)
    end
  end

  describe ".applicable_date_for" do
    it "uses tenant timezone when configured" do
      tenant = create(:tenant, settings: { "timezone" => "America/Bogota" })
      now = Time.utc(2026, 4, 15, 2, 30, 0)

      date = described_class.applicable_date_for(tenant:, now:)

      expect(date).to eq(Date.new(2026, 4, 14))
    end

    it "falls back to America/Bogota when timezone is invalid" do
      tenant = create(:tenant, settings: { "timezone" => "Invalid/Zone" })
      now = Time.utc(2026, 4, 15, 2, 30, 0)

      date = described_class.applicable_date_for(tenant:, now:)

      expect(date).to eq(Date.new(2026, 4, 14))
    end
  end
end
