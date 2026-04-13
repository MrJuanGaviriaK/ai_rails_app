module Admin
  class MineralPurchasesController < ApplicationController
    before_action :set_tenant
    before_action :require_mineral_purchase_access!
    before_action :require_buyer_access!, only: %i[new create]
    before_action :set_mineral_purchase, only: %i[show retry_signature start_signature complete_signature]

    def index
      @mineral_purchases = scoped_mineral_purchases
        .includes(:seller, :buyer, :e_signature_request)
        .latest_first
    end

    def show
    end

    def retry_signature
      result = MineralPurchases::RetrySignature.call(actor: current_user, mineral_purchase: @mineral_purchase)

      if result.success?
        redirect_to admin_mineral_purchase_path(@mineral_purchase), notice: t("admin.mineral_purchases.flash.retry_started")
      else
        redirect_to admin_mineral_purchase_path(@mineral_purchase), alert: result.error
      end
    end

    def start_signature
      result = MineralPurchases::Signature::StartEmbeddedSigning.call(mineral_purchase: @mineral_purchase, actor: current_user)

      if result.success? && result.sign_url.present?
        @sign_url = result.sign_url
        @client_id = result.e_signature_request.integration.credentials["client_id"].to_s

        if @client_id.blank?
          redirect_to admin_mineral_purchase_path(@mineral_purchase), alert: t("admin.mineral_purchases.errors.missing_client_id")
          return
        end

        render :start_signature
      elsif result.success?
        redirect_to admin_mineral_purchase_path(@mineral_purchase), notice: t("admin.mineral_purchases.flash.already_signed")
      else
        redirect_to admin_mineral_purchase_path(@mineral_purchase), alert: result.error
      end
    end

    def complete_signature
      result = MineralPurchases::Signature::Complete.call(mineral_purchase: @mineral_purchase, actor: current_user, request:)

      if result.success?
        redirect_to admin_mineral_purchase_path(@mineral_purchase), notice: t("admin.mineral_purchases.flash.completed")
      else
        redirect_to admin_mineral_purchase_path(@mineral_purchase), alert: result.error
      end
    end

    def new
      @mineral_purchase = @tenant.mineral_purchases.new
      @mineral_purchase.purchasing_location = current_user.purchasing_location
      load_approved_sellers
    end

    def create
      result = MineralPurchases::Create.call(
        actor: current_user,
        tenant: @tenant,
        attributes: mineral_purchase_params
      )

      @mineral_purchase = result.mineral_purchase

      if result.success?
        redirect_to admin_mineral_purchase_path(@mineral_purchase), notice: t("admin.mineral_purchases.flash.created")
      else
        load_approved_sellers
        flash.now[:alert] = t("admin.mineral_purchases.flash.fix_errors")
        render :new, status: :unprocessable_entity
      end
    end

    private

    def mineral_purchase_params
      params.require(:mineral_purchase).permit(:seller_id, :mineral_type, :fine_grams, :total_price_cop, :purchasing_location_id, :miner_live_photo_signed_id)
    end

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.mineral_purchases.authorization.not_allowed")
    end

    def require_mineral_purchase_access!
      return if current_user&.buyer_for_tenant?(@tenant)
      return if current_user&.admin_for_tenant?(@tenant)

      redirect_to dashboard_path, alert: t("admin.mineral_purchases.authorization.not_allowed")
    end

    def require_buyer_access!
      return if current_user&.buyer_for_tenant?(@tenant)

      redirect_to admin_mineral_purchases_path, alert: t("admin.mineral_purchases.authorization.buyer_required")
    end

    def set_mineral_purchase
      @mineral_purchase = scoped_mineral_purchases.find(params[:id])
    end

    def scoped_mineral_purchases
      scope = @tenant.mineral_purchases
      return scope if current_user&.admin_for_tenant?(@tenant)

      scope.where(buyer_id: current_user.id)
    end

    def load_approved_sellers
      @approved_sellers = @tenant.sellers.where(status: "approved").order(:first_name, :last_name)
    end
  end
end
