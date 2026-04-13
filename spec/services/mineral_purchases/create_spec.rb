require "rails_helper"

RSpec.describe MineralPurchases::Create do
  def create_test_image_blob_signed_id
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image"),
      filename: "miner.jpg",
      content_type: "image/jpeg"
    )

    blob.signed_id
  end

  describe ".call" do
    it "creates purchase and single draft e-signature request" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      create(
        :e_signature_template,
        tenant:,
        integration:,
        title: "seller_contract_accounts_for_participation_v1",
        signer_roles: [ { "name" => "SELLER", "order" => 0 } ],
        custom_fields: [
          { "name" => "SELLER_FULLNAME" },
          { "name" => "SELLER_IDENTIFICATION" },
          { "name" => "SELLER_GRAMS" },
          { "name" => "SELLER_TOTAL_PRICE" }
        ]
      )

      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")

      expect do
        result = described_class.call(
          actor: buyer,
          tenant:,
          attributes: {
            seller_id: seller.id,
            mineral_type: "gold",
            fine_grams: "12.57",
            total_price_cop: "500000.42",
            miner_live_photo_signed_id: create_test_image_blob_signed_id
          }
        )

        expect(result.success?).to be(true)
        expect(result.mineral_purchase.e_signature_request).to be_present
        expect(result.mineral_purchase.e_signature_request.status).to eq("draft")
        expect(result.mineral_purchase.miner_live_photo).to be_attached
      end.to change(MineralPurchase, :count).by(1).and change(ESignatureRequest, :count).by(1)
    end

    it "returns error when template is missing" do
      tenant = create(:tenant)
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")

      result = described_class.call(
        actor: buyer,
        tenant:,
        attributes: {
          seller_id: seller.id,
          mineral_type: "gold",
          fine_grams: "2.00",
          total_price_cop: "100.00",
          miner_live_photo_signed_id: create_test_image_blob_signed_id
        }
      )

      expect(result.success?).to be(false)
      expect(result.errors.join(" ")).to include(I18n.t("admin.mineral_purchases.errors.template_not_found"))
    end

    it "returns error when live photo is missing" do
      tenant = create(:tenant)
      integration = create(:integration, tenant:, provider: "dropbox_sign", status: "active")
      create(:e_signature_template, tenant:, integration:, title: "seller_contract_accounts_for_participation_v1")
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      seller = create(:seller, tenant:, status: "approved")

      result = described_class.call(
        actor: buyer,
        tenant:,
        attributes: {
          seller_id: seller.id,
          mineral_type: "gold",
          fine_grams: "2.00",
          total_price_cop: "100.00"
        }
      )

      expect(result.success?).to be(false)
      expect(result.errors.join(" ")).to include(I18n.t("errors.messages.blank"))
    end
  end
end
