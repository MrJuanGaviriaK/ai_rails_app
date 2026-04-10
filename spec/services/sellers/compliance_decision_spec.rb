require "rails_helper"

RSpec.describe Sellers::ComplianceDecision do
  describe ".call" do
    let(:tenant) { create(:tenant) }
    let(:officer) do
      create(:user).tap { |user| user.add_role(:compliance_officer, tenant) }
    end

    it "approves seller in review" do
      seller = create(:seller, tenant:, status: "in_review")

      result = described_class.call(seller:, actor: officer, decision: :approve)

      expect(result.success?).to be(true)
      expect(seller.reload.status).to eq("approved")
    end

    it "requires reason when rejecting" do
      seller = create(:seller, tenant:, status: "in_review")

      result = described_class.call(seller:, actor: officer, decision: :reject, rejection_reason: "")

      expect(result.success?).to be(false)
      expect(seller.reload.status).to eq("in_review")
    end
  end
end
