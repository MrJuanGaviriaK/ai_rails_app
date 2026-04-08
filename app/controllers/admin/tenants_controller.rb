class Admin::TenantsController < Admin::BaseController
  before_action :set_tenant, only: %i[edit update destroy]

  def index
    @tenants = Tenant.kept.order(:name)
    @tenants = @tenants.where(status: params[:status]) if params[:status].present?

    if params[:query].present?
      pattern = "%#{params[:query].strip}%"
      @tenants = @tenants.where("name ILIKE :pattern OR slug ILIKE :pattern", pattern: pattern)
    end
  end

  def new
    @tenant = Tenant.new(status: "active")
  end

  def create
    @tenant = Tenant.new(tenant_params)
    apply_settings_json(@tenant)

    if @tenant.errors.none? && @tenant.save
      redirect_to admin_tenants_path, notice: t("admin.tenants.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @tenant.assign_attributes(tenant_params)
    apply_settings_json(@tenant)

    if @tenant.errors.none? && @tenant.save
      redirect_to admin_tenants_path, notice: t("admin.tenants.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tenant.soft_delete!
    redirect_to admin_tenants_path, notice: t("admin.tenants.flash.archived")
  end

  private

  def set_tenant
    @tenant = Tenant.kept.find(params[:id])
  end

  def tenant_params
    params.require(:tenant).permit(:name, :slug, :status)
  end

  def apply_settings_json(tenant)
    raw_settings = params.dig(:tenant, :settings_json)
    return if raw_settings.blank?

    parsed_settings = JSON.parse(raw_settings)
    unless parsed_settings.is_a?(Hash)
      tenant.errors.add(:settings, t("admin.tenants.errors.settings_must_be_object"))
      return
    end

    tenant.settings = parsed_settings
  rescue JSON::ParserError
    tenant.errors.add(:settings, t("admin.tenants.errors.settings_must_be_valid_json"))
  end
end
