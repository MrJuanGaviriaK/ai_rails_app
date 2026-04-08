class Admin::PurchasingLocationsController < ApplicationController
  before_action :require_purchasing_location_access!
  before_action :set_purchasing_location, only: %i[show edit update destroy]

  def index
    @purchasing_locations = scoped_purchasing_locations.order(:name)

    if params[:query].present?
      pattern = "%#{params[:query].strip}%"
      @purchasing_locations = @purchasing_locations.where(
        "name ILIKE :pattern OR city ILIKE :pattern OR address ILIKE :pattern",
        pattern: pattern
      )
    end

    @purchasing_locations = @purchasing_locations.where(department: params[:department]) if params[:department].present?
  end

  def show
  end

  def new
    @purchasing_location = PurchasingLocation.new(active: true)
    assign_default_tenant(@purchasing_location)
  end

  def create
    @purchasing_location = PurchasingLocation.new(purchasing_location_params)
    enforce_tenant_scope_for_admin(@purchasing_location)

    if @purchasing_location.save
      redirect_to admin_purchasing_location_path(@purchasing_location), notice: t("admin.purchasing_locations.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @purchasing_location.assign_attributes(purchasing_location_params)
    enforce_tenant_scope_for_admin(@purchasing_location)

    if @purchasing_location.save
      redirect_to admin_purchasing_location_path(@purchasing_location), notice: t("admin.purchasing_locations.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @purchasing_location.soft_delete!
    redirect_to admin_purchasing_locations_path, notice: t("admin.purchasing_locations.flash.archived")
  end

  private

  def set_purchasing_location
    @purchasing_location = scoped_purchasing_locations.find(params[:id])
  end

  def scoped_purchasing_locations
    base_scope = PurchasingLocation.kept.includes(:tenant)
    return base_scope if current_user.superadmin?

    return PurchasingLocation.none unless current_tenant

    base_scope.where(tenant_id: current_tenant.id)
  end

  def purchasing_location_params
    permitted = %i[name department city address active notes]
    permitted << :tenant_id if current_user.superadmin?

    params.require(:purchasing_location).permit(permitted)
  end

  def enforce_tenant_scope_for_admin(record)
    return if current_user.superadmin?

    record.tenant = current_tenant
  end

  def assign_default_tenant(record)
    if current_user.superadmin?
      record.tenant ||= switchable_tenants.first
    else
      record.tenant = current_tenant
    end
  end

  def require_purchasing_location_access!
    return if current_user&.superadmin?
    return if current_user&.admin_for_tenant?(current_tenant)

    redirect_to dashboard_path, alert: t("admin.purchasing_locations.authorization.not_allowed")
  end
end
