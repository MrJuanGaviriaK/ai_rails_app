module Admin
  class MineralPurchaseDirectUploadsController < ApplicationController
    include ActiveStorage::SetCurrent

    before_action :set_tenant
    before_action :require_mineral_purchase_access!

    def create
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        **blob_args,
        key: build_key(blob_args[:filename])
      )

      render json: direct_upload_json(blob)
    end

    private

    def blob_args
      params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, metadata: {}).to_h.symbolize_keys
    end

    def direct_upload_json(blob)
      blob.as_json(root: false, methods: :signed_id).merge(
        direct_upload: {
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload
        }
      )
    end

    def build_key(filename)
      extension = File.extname(filename.to_s)
      sanitized_basename = File.basename(filename.to_s, extension).parameterize.presence || "capture"

      "mineral_purchases/#{@tenant.id}/#{SecureRandom.uuid}-#{sanitized_basename}#{extension}"
    end

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      head :forbidden
    end

    def require_mineral_purchase_access!
      return if current_user&.buyer_for_tenant?(@tenant)
      return if current_user&.admin_for_tenant?(@tenant)

      head :forbidden
    end
  end
end
