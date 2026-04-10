class Admin::UsersController < ApplicationController
  before_action :require_user_management_access!
  before_action :set_status_filter, only: :index
  before_action :set_form_options, only: %i[new create]
  before_action :set_user, only: %i[destroy restore]

  def index
    @users = filtered_users_scope
      .includes(:roles)
      .order(created_at: :desc)

    tenant_ids = @users.flat_map do |user|
      user.roles.select { |role| role.resource_type == "Tenant" }.map(&:resource_id)
    end

    @tenant_name_by_id = Tenant.where(id: tenant_ids.uniq).pluck(:id, :name).to_h
  end

  def new
    @user = User.new
  end

  def create
    result = Admin::Users::Provision.call(
      actor: current_user,
      current_tenant: current_tenant,
      attributes: user_params
    )

    @user = result.user
    @selected_role = result.selected_role
    @selected_tenant_id = result.selected_tenant_id
    @selected_purchasing_location_id = result.selected_purchasing_location_id

    if result.success?
      redirect_to admin_users_path, notice: t("admin.users.flash.created")
    else
      set_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if !current_user.superadmin? && @user.superadmin?
      redirect_to admin_users_path, alert: t("admin.users.authorization.not_allowed")
      return
    end

    @user.soft_delete!
    redirect_to admin_users_path, notice: t("admin.users.flash.archived")
  end

  def restore
    if !current_user.superadmin? && @user.superadmin?
      redirect_to admin_users_path, alert: t("admin.users.authorization.not_allowed")
      return
    end

    @user.restore!
    redirect_to admin_users_path(status: "archived"), notice: t("admin.users.flash.restored")
  end

  private

  def require_user_management_access!
    return if current_user&.superadmin?
    return if current_user&.admin_for_tenant?(current_tenant)

    redirect_to dashboard_path, alert: t("admin.users.authorization.not_allowed")
  end

  def user_params
    params.require(:user).permit(
      :name,
      :email,
      :password,
      :password_confirmation,
      :role,
      :tenant_id,
      :purchasing_location_id
    )
  end

  def set_form_options
    @role_options = if current_user.superadmin?
      %w[superadmin admin buyer client compliance_officer]
    else
      %w[admin buyer client compliance_officer]
    end

    @available_tenants = Tenant.active_context.order(:name)
    @available_purchasing_locations = scoped_purchasing_locations.order(:name)
  end

  def scoped_purchasing_locations
    base_scope = PurchasingLocation.kept.where(active: true).includes(:tenant)

    return base_scope.where(tenant_id: selected_tenant_id) if selected_tenant_id.present?
    return base_scope if current_user.superadmin?

    PurchasingLocation.none
  end

  def selected_tenant_id
    return current_tenant&.id unless current_user.superadmin?

    @selected_tenant_id.presence || params.dig(:user, :tenant_id).presence || current_tenant&.id
  end

  def set_status_filter
    @status_filter = params[:status].presence_in(%w[active archived all]) || "active"
  end

  def filtered_users_scope
    scope = if current_user.superadmin?
      User.all
    elsif current_tenant.present?
      User.with_role_for_tenant(current_tenant)
    else
      User.none
    end

    case @status_filter
    when "archived"
      scope.archived
    when "all"
      scope
    else
      scope.kept
    end
  end

  def set_user
    @user = if current_user.superadmin?
      User.find(params[:id])
    elsif current_tenant.present?
      User.with_role_for_tenant(current_tenant).find(params[:id])
    else
      User.none.find(params[:id])
    end
  end
end
