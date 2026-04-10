module Admin
  class SellersController < ApplicationController
    before_action :set_tenant
    before_action :require_seller_access!
    before_action :require_buyer_access!, only: %i[new create]
    before_action :set_seller, only: :show

    def index
      @status_filter = params[:status].presence_in(Seller::STATUSES)
      @seller_type_filter = params[:seller_type].presence_in(Seller::SELLER_TYPES)
      @query = params[:query].to_s

      @sellers = @tenant.sellers
        .with_status(@status_filter)
        .with_seller_type(@seller_type_filter)
        .search(@query)
        .includes(:seller_documents)
        .order(created_at: :desc)
    end

    def show
      @latest_consent = @seller.e_signature_requests.latest_first.first
      @can_decide_compliance = current_user.compliance_officer_for_tenant?(@tenant)
      @can_start_consent = current_user.buyer_for_tenant?(@tenant) && @seller.pending?
    end

    def new
      @seller = @tenant.sellers.new(status: "pending")
    end

    def create
      result = Sellers::Create.call(
        actor: current_user,
        tenant: @tenant,
        attributes: seller_params,
        identification_file: params.dig(:seller, :identification_file)
      )

      @seller = result.seller

      if result.success?
        redirect_to admin_seller_path(@seller), notice: t("admin.sellers.flash.created")
      else
        flash.now[:alert] = t("admin.sellers.flash.fix_errors")
        render :new, status: :unprocessable_entity
      end
    end

    private

    def seller_params
      params.require(:seller).permit(
        :first_name,
        :last_name,
        :identification_type,
        :identification_number,
        :seller_type,
        :department,
        :city,
        :address,
        :phone,
        :email
      )
    end

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.sellers.authorization.not_allowed")
    end

    def require_seller_access!
      return if current_user&.seller_workflow_access_for_tenant?(@tenant)

      redirect_to dashboard_path, alert: t("admin.sellers.authorization.not_allowed")
    end

    def require_buyer_access!
      return if current_user&.buyer_for_tenant?(@tenant)

      redirect_to admin_sellers_path, alert: t("admin.sellers.authorization.buyer_required")
    end

    def set_seller
      @seller = @tenant.sellers.includes(:e_signature_requests, seller_documents: { file_attachment: :blob }).find(params[:id])
    end
  end
end
