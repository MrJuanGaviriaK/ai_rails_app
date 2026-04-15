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

  describe "GET /admin/mineral_purchases/new" do
    it "renders daily price availability stimulus wiring" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      get new_admin_mineral_purchase_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"mineral-purchase-daily-price\"")
      expect(response.body).to include("data-mineral-purchase-daily-price-url-value=\"#{daily_price_availability_admin_mineral_purchases_path}\"")
      expect(response.body).to include("data-mineral-purchase-daily-price-target=\"submitButton\"")
      expect(response.body).to include("data-mineral-purchase-daily-price-target=\"totalDisplay\"")
      expect(response.body).to include("readonly")
    end
  end

  describe "GET /admin/mineral_purchases/daily_price_availability" do
    let(:buyer) { create(:user) }

    before do
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
    end

    it "returns available true when approved daily price exists" do
      applicable_date = DailyPrices::Resolver.applicable_date_for(tenant:)
      create(:daily_price, :approved, tenant:, mineral_type: "oro", unit_price_cop: 345_678.91, price_date: applicable_date)

      get daily_price_availability_admin_mineral_purchases_path, params: { mineral_type: "oro" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "available" => true,
        "applicable_date" => applicable_date.iso8601,
        "unit_price_cop" => "345678.91"
      )
      expect(payload).not_to have_key("message")
    end

    it "returns available false with localized message when approved daily price is missing" do
      get daily_price_availability_admin_mineral_purchases_path, params: { mineral_type: "oro" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "available" => false,
        "unit_price_cop" => nil,
        "message" => I18n.t("admin.mineral_purchases.errors.daily_price_not_approved")
      )
    end

    it "returns unprocessable entity when mineral_type param is missing" do
      get daily_price_availability_admin_mineral_purchases_path

      expect(response).to have_http_status(:unprocessable_entity)
      payload = JSON.parse(response.body)
      expect(payload).to include("error" => I18n.t("errors.messages.blank"))
    end

    it "uses DailyPrices::Resolver to resolve availability" do
      applicable_date = Date.new(2026, 4, 15)
      resolver_result = DailyPrices::Resolver::Result.new(success?: false, daily_price: nil, error: :daily_price_not_approved)

      allow(DailyPrices::Resolver).to receive(:applicable_date_for).with(tenant:).and_return(applicable_date)
      expect(DailyPrices::Resolver).to receive(:call).with(tenant:, mineral_type: "oro", on_date: applicable_date).and_return(resolver_result)

      get daily_price_availability_admin_mineral_purchases_path, params: { mineral_type: "oro" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["available"]).to be(false)
    end
  end

  describe "POST /admin/mineral_purchases" do
    it "creates purchase for approved seller" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved")
      approved_daily_price = create(
        :daily_price,
        :approved,
        tenant:,
        mineral_type: "oro",
        unit_price_cop: 321_000.88,
        price_date: DailyPrices::Resolver.applicable_date_for(tenant:)
      )

      expect do
        post admin_mineral_purchases_path, params: {
          mineral_purchase: {
            seller_id: seller.id,
            mineral_type: "oro",
            fine_grams: "8.50",
            total_price_cop: "99.99",
            miner_live_photo_signed_id: create_test_image_blob_signed_id
          }
        }
      end.to change(MineralPurchase, :count).by(1).and change(ESignatureRequest, :count).by(1)

      purchase = MineralPurchase.last
      expect(response).to redirect_to(admin_mineral_purchase_path(purchase))
      expect(purchase.status).to eq("created")
      expect(purchase.e_signature_request.status).to eq("draft")
      expect(purchase.daily_price_id).to eq(approved_daily_price.id)
      expect(purchase.total_price_cop.to_s("F")).to eq("2728507.48")
    end

    it "rejects non-approved sellers" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "pending")
      create(:daily_price, :approved, tenant:, mineral_type: "oro", price_date: DailyPrices::Resolver.applicable_date_for(tenant:))

      post admin_mineral_purchases_path, params: {
        mineral_purchase: {
            seller_id: seller.id,
            mineral_type: "oro",
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
      create(:daily_price, :approved, tenant:, mineral_type: "oro", price_date: DailyPrices::Resolver.applicable_date_for(tenant:))

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

    it "blocks creation when approved daily price does not exist" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)
      seller = create(:seller, tenant:, status: "approved")

      post admin_mineral_purchases_path, params: {
        mineral_purchase: {
          seller_id: seller.id,
          mineral_type: "oro",
          fine_grams: "8.50",
          total_price_cop: "100000.75",
          miner_live_photo_signed_id: create_test_image_blob_signed_id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.mineral_purchases.errors.daily_price_not_approved"))
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
