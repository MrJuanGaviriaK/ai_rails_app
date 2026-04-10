require "rails_helper"

RSpec.describe "Admin::Sellers", type: :request do
  let(:tenant) { create(:tenant) }
  let(:integration) { create(:integration, tenant:) }
  let(:template) { create(:e_signature_template, tenant:, integration:, title: "seller_habeas_data_consent_v1") }

  before { template }

  describe "GET /admin/sellers" do
    it "allows users with buyer role in tenant" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      get admin_sellers_path

      expect(response).to have_http_status(:ok)
    end

    it "blocks users without seller workflow access" do
      user = create(:user)
      sign_in_as(user)

      get admin_sellers_path

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "POST /admin/sellers" do
    it "creates seller and identification document" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      file = fixture_file_upload("sample.pdf", "application/pdf")

      expect do
        post admin_sellers_path, params: {
          seller: {
            first_name: "Juan",
            last_name: "Lopez",
            identification_type: "cc",
            identification_number: "123.456",
            seller_type: "subsistence_miner",
            department: "Antioquia",
            city: "Medellin",
            address: "Calle 1",
            phone: "3001231234",
            email: "seller@example.com",
            identification_file: file
          }
        }
      end.to change(Seller, :count).by(1).and change(SellerDocument, :count).by(1).and change(ESignatureRequest, :count).by(1)

      seller = Seller.last
      expect(seller.status).to eq("pending")
      expect(seller.identification_number).to eq("123456")
      expect(response).to redirect_to(admin_seller_path(seller))
    end
  end

  describe "POST /admin/sellers/:id/approve" do
    it "approves in_review seller for compliance officer" do
      officer = create(:user)
      officer.add_role(:compliance_officer, tenant)
      sign_in_as(officer)
      seller = create(:seller, tenant:, status: "in_review")

      post approve_admin_seller_path(seller)

      expect(response).to redirect_to(admin_seller_path(seller))
      expect(seller.reload.status).to eq("approved")
      expect(seller.reviewed_by).to eq(officer)
    end
  end

  describe "POST /admin/sellers/:id/reject" do
    it "requires rejection reason" do
      officer = create(:user)
      officer.add_role(:compliance_officer, tenant)
      sign_in_as(officer)
      seller = create(:seller, tenant:, status: "in_review")

      post reject_admin_seller_path(seller), params: { rejection_reason: "" }

      expect(response).to redirect_to(admin_seller_path(seller))
      expect(seller.reload.status).to eq("in_review")
    end
  end

  describe "POST /admin/sellers/:id/start" do
    it "renders embedded signing screen inside the app" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      seller = create(:seller, tenant:, status: "pending", email: "seller@example.com")
      request_record = create(:e_signature_request, requestable: seller, tenant:, integration:, e_signature_template: template)

      allow(Sellers::Consent::StartEmbeddedSigning).to receive(:call).with(seller:, actor: buyer).and_return(
        Sellers::Consent::StartEmbeddedSigning::Result.new(
          e_signature_request: request_record,
          sign_url: "https://app.hellosign.com/editor/embeddedSign?signature_id=sig_123&token=abc",
          error: nil
        )
      )

      post start_admin_seller_path(seller)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"e-signature-signing\"")
      expect(response.body).to include("embeddedSign")
    end
  end

  describe "GET /admin/sellers/:id" do
    it "shows e-signature requests associated to the seller" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      seller = create(:seller, tenant:)
      request_record = create(
        :e_signature_request,
        requestable: seller,
        tenant:,
        integration:,
        e_signature_template: template,
        status: "draft"
      )

      get admin_seller_path(seller)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("##{request_record.id}")
      expect(response.body).to include(template.title)
    end
  end
end
