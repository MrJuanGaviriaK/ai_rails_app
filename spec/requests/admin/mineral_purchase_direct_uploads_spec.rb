require "rails_helper"
require "digest/md5"

RSpec.describe "Admin::MineralPurchaseDirectUploads", type: :request do
  describe "POST /admin/mineral_purchase_direct_uploads" do
    it "creates direct upload blob with mineral_purchases key prefix" do
      tenant = create(:tenant)
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      content = "fake image content"

      post admin_mineral_purchase_direct_uploads_path, params: {
        blob: {
          filename: "miner.jpg",
          byte_size: content.bytesize,
          checksum: Digest::MD5.base64digest(content),
          content_type: "image/jpeg",
          metadata: {}
        }
      }

      expect(response).to have_http_status(:ok)

      payload = JSON.parse(response.body)
      blob = ActiveStorage::Blob.find_signed!(payload.fetch("signed_id"))

      expect(blob.key).to start_with("mineral_purchases/#{tenant.id}/")
    end
  end
end
