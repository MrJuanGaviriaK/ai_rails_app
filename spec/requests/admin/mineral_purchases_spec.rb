require "rails_helper"

RSpec.describe "Admin::MineralPurchases", type: :request do
  def create_test_image_blob_signed_id
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image"),
      filename: "miner.jpg",
      content_type: "image/jpeg"
    )

    blob.signed_id
  end

  let(:tenant) { create(:tenant) }
  let(:integration) { create(:integration, tenant:, provider: "dropbox_sign", status: "active") }

  before do
    create(
      :e_signature_template,
      tenant:,
      integration:,
      title: "seller_contract_accounts_for_participation_v1",
      signer_roles: [ { "name" => "SELLER", "order" => 0 } ]
    )
  end

  describe "GET /admin/mineral_purchases" do
    it "allows buyer users" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      get admin_mineral_purchases_path

      expect(response).to have_http_status(:ok)
    end

    it "blocks unauthorized users" do
      user = create(:user)
      sign_in_as(user)

      get admin_mineral_purchases_path

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "POST /admin/mineral_purchases" do
    it "creates purchase for approved seller" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved")

      expect do
        post admin_mineral_purchases_path, params: {
          mineral_purchase: {
            seller_id: seller.id,
            mineral_type: "gold",
            fine_grams: "8.50",
            total_price_cop: "100000.75",
            miner_live_photo_signed_id: create_test_image_blob_signed_id
          }
        }
      end.to change(MineralPurchase, :count).by(1).and change(ESignatureRequest, :count).by(1)

      expect(response).to redirect_to(admin_mineral_purchase_path(MineralPurchase.last))
      expect(MineralPurchase.last.status).to eq("created")
      expect(MineralPurchase.last.e_signature_request.status).to eq("draft")
    end

    it "rejects non-approved sellers" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "pending")

      post admin_mineral_purchases_path, params: {
        mineral_purchase: {
            seller_id: seller.id,
            mineral_type: "gold",
            fine_grams: "8.50",
            total_price_cop: "100000.75",
            miner_live_photo_signed_id: create_test_image_blob_signed_id
          }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows localized error when seller is missing" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      post admin_mineral_purchases_path, params: {
        mineral_purchase: {
          seller_id: "",
          mineral_type: "oro",
          fine_grams: "8.50",
          total_price_cop: "100000.75",
          miner_live_photo_signed_id: create_test_image_blob_signed_id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "POST /admin/mineral_purchases/:id/retry_signature" do
    it "retries signature by replacing failed request" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_failed")
      failed_request = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: ESignatureTemplate.find_by!(tenant:, title: "seller_contract_accounts_for_participation_v1"),
        status: "failed",
        failure_reason: "boom"
      )

      expect do
        post retry_signature_admin_mineral_purchase_path(purchase)
      end.to change(ESignatureRequest, :count).by(0)

      expect(response).to redirect_to(admin_mineral_purchase_path(purchase))
      expect(purchase.reload.status).to eq("created")
      expect(purchase.e_signature_request).to be_present
      expect(purchase.e_signature_request.id).not_to eq(failed_request.id)
      expect(purchase.e_signature_request.status).to eq("draft")
    end

    it "allows tenant admin to retry failed signature" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)
      seller = create(:seller, tenant:, status: "approved")
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_failed")

      create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: ESignatureTemplate.find_by!(tenant:, title: "seller_contract_accounts_for_participation_v1"),
        status: "failed",
        failure_reason: "boom"
      )

      post retry_signature_admin_mineral_purchase_path(purchase)

      expect(response).to redirect_to(admin_mineral_purchase_path(purchase))
      expect(purchase.reload.status).to eq("created")
      expect(purchase.e_signature_request.status).to eq("draft")
    end
  end

  describe "GET /admin/mineral_purchases/:id/start_signature" do
    it "renders embedded signer view" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved", email: "seller@example.com")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "signature_pending")
      request_record = create(
        :e_signature_request,
        requestable: purchase,
        tenant:,
        integration:,
        e_signature_template: ESignatureTemplate.find_by!(tenant:, title: "seller_contract_accounts_for_participation_v1"),
        status: "awaiting_signature",
        provider_signature_request_id: "req_123",
        provider_signature_id: "sig_123"
      )

      allow(MineralPurchases::Signature::StartEmbeddedSigning).to receive(:call).with(mineral_purchase: purchase, actor: buyer).and_return(
        MineralPurchases::Signature::StartEmbeddedSigning::Result.new(
          e_signature_request: request_record,
          sign_url: "https://app.hellosign.com/editor/embeddedSign?signature_id=sig_123&token=abc",
          error: nil
        )
      )

      get start_signature_admin_mineral_purchase_path(purchase)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"e-signature-signing\"")
    end
  end

  describe "GET /admin/mineral_purchases/:id" do
    it "shows links for signed documents" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved")
      purchase = create(:mineral_purchase, tenant:, buyer:, seller:, status: "completed")

      purchase.signed_documents.attach(
        io: StringIO.new("%PDF-1.7 fake"),
        filename: "signed-contract.pdf",
        content_type: "application/pdf"
      )

      get admin_mineral_purchase_path(purchase)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("signed-contract.pdf")
    end
  end
end
