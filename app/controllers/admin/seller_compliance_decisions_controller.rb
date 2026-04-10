module Admin
  class SellerComplianceDecisionsController < ApplicationController
    before_action :set_tenant
    before_action :set_seller
    before_action :require_compliance_access!

    def approve
      result = Sellers::ComplianceDecision.call(seller: @seller, actor: current_user, decision: :approve)

      if result.success?
        redirect_to admin_seller_path(@seller), notice: t("admin.seller_compliance.flash.approved")
      else
        redirect_to admin_seller_path(@seller), alert: result.error
      end
    end

    def reject
      result = Sellers::ComplianceDecision.call(
        seller: @seller,
        actor: current_user,
        decision: :reject,
        rejection_reason: params[:rejection_reason]
      )

      if result.success?
        redirect_to admin_seller_path(@seller), notice: t("admin.seller_compliance.flash.rejected")
      else
        redirect_to admin_seller_path(@seller), alert: result.error
      end
    end

    private

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.seller_compliance.authorization.not_allowed")
    end

    def set_seller
      @seller = @tenant.sellers.find(params[:id])
    end

    def require_compliance_access!
      return if current_user&.compliance_officer_for_tenant?(@tenant)

      redirect_to admin_seller_path(@seller), alert: t("admin.seller_compliance.authorization.not_allowed")
    end
  end
end
