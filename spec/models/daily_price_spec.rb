require "rails_helper"

RSpec.describe DailyPrice, type: :model do
  describe "validations" do
    it "allows only configured mineral types" do
      daily_price = build(:daily_price, mineral_type: "palladium")

      expect(daily_price).not_to be_valid
      expect(daily_price.errors[:mineral_type]).to be_present
    end

    it "requires a positive unit price" do
      daily_price = build(:daily_price, unit_price_cop: 0)

      expect(daily_price).not_to be_valid
      expect(daily_price.errors[:unit_price_cop]).to be_present
    end

    it "requires rejection reason when rejected" do
      daily_price = build(:daily_price, state: "rejected", rejected_at: Time.current, rejection_reason: "")

      expect(daily_price).not_to be_valid
      expect(daily_price.errors[:rejection_reason]).to be_present
    end

    it "enforces one approved price per tenant/mineral/date" do
      tenant = create(:tenant)
      create(:daily_price, :approved, tenant:, mineral_type: "oro", price_date: Date.current)

      expect do
        create(:daily_price, :approved, tenant:, mineral_type: "oro", price_date: Date.current)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "state transitions" do
    it "approves a pending daily price with reviewer and timestamp" do
      reviewer = create(:user)
      daily_price = create(:daily_price, state: "pending")

      daily_price.approve!(actor: reviewer)

      expect(daily_price.reload.state).to eq("approved")
      expect(daily_price.reviewed_by).to eq(reviewer)
      expect(daily_price.approved_at).to be_present
      expect(daily_price.rejected_at).to be_nil
    end

    it "rejects a pending daily price with reason" do
      reviewer = create(:user)
      daily_price = create(:daily_price, state: "pending")

      daily_price.reject!(actor: reviewer, rejection_reason: "Outlier detected")

      expect(daily_price.reload.state).to eq("rejected")
      expect(daily_price.reviewed_by).to eq(reviewer)
      expect(daily_price.rejected_at).to be_present
      expect(daily_price.rejection_reason).to eq("Outlier detected")
    end

    it "moves rejected daily price back to pending" do
      daily_price = create(:daily_price, :rejected)

      daily_price.mark_pending!

      expect(daily_price.reload.state).to eq("pending")
      expect(daily_price.reviewed_by).to be_nil
      expect(daily_price.rejected_at).to be_nil
      expect(daily_price.rejection_reason).to be_nil
    end

    it "raises invalid transition when trying to approve approved record" do
      daily_price = create(:daily_price, :approved)

      expect do
        daily_price.approve!(actor: create(:user))
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
