module Admin
  class SellerConsentsController < ApplicationController
    before_action :set_tenant
    before_action :set_seller
    before_action :require_buyer_access!

    def start
      result = Sellers::Consent::StartEmbeddedSigning.call(seller: @seller, actor: current_user)

      if result.success? && result.sign_url.present?
        @sign_url = result.sign_url
        @client_id = result.e_signature_request.integration.credentials["client_id"].to_s

        if @client_id.blank?
          redirect_to admin_seller_path(@seller), alert: t("admin.seller_consents.errors.missing_client_id")
          return
        end

        render :start
      elsif result.success?
        redirect_to admin_seller_path(@seller), notice: t("admin.seller_consents.flash.already_signed")
      else
        redirect_to admin_seller_path(@seller), alert: result.error
      end
    end

    def complete
      result = Sellers::Consent::Complete.call(seller: @seller, actor: current_user, request:)

      if result.success?
        redirect_to admin_seller_path(@seller), notice: t("admin.seller_consents.flash.completed")
      else
        redirect_to admin_seller_path(@seller), alert: result.error
      end
    end

    private

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.sellers.authorization.not_allowed")
    end

    def set_seller
      @seller = @tenant.sellers.find(params[:id])
    end

    def require_buyer_access!
      return if current_user&.buyer_for_tenant?(@tenant)

      redirect_to admin_seller_path(@seller), alert: t("admin.sellers.authorization.buyer_required")
    end
  end
end
