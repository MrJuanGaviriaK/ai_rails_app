require "rails_helper"

RSpec.describe Sellers::StatusTransitioner do
  describe ".call" do
    it "moves seller to in_review when requirements are present" do
      seller = create(:seller, status: "pending")
      create(:seller_document, seller:, kind: "identification")
      create(:seller_document, seller:, kind: "habeas_data_consent_signed")

      result = described_class.call(seller:)

      expect(result.changed).to be(true)
      expect(seller.reload.status).to eq("in_review")
    end

    it "keeps pending when signed consent is missing" do
      seller = create(:seller, status: "pending")
      create(:seller_document, seller:, kind: "identification")

      result = described_class.call(seller:)

      expect(result.changed).to be(false)
      expect(seller.reload.status).to eq("pending")
    end
  end
end
