class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_current_context

  helper_method :current_tenant, :switchable_tenants

  def after_sign_in_path_for(resource)
    dashboard_path
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  def current_tenant
    Current.tenant
  end

  def switchable_tenants
    return Tenant.active_context.order(:name) if current_user&.superadmin?

    Tenant.none
  end

  def set_current_context
    Current.user = nil
    Current.tenant = nil
    return unless user_signed_in?

    Current.user = current_user
    Current.tenant = resolve_current_tenant
  end

  def resolve_current_tenant
    selected_tenant = Tenant.active_context.find_by(id: session[:current_tenant_id])
    return selected_tenant if tenant_allowed_for_current_user?(selected_tenant)

    session.delete(:current_tenant_id)

    fallback_tenant = fallback_tenant_for_current_user
    session[:current_tenant_id] = fallback_tenant.id if fallback_tenant
    fallback_tenant
  end

  def tenant_allowed_for_current_user?(tenant)
    return false unless tenant
    return true if current_user.superadmin?

    current_user.accessible_tenants.exists?(id: tenant.id)
  end

  def fallback_tenant_for_current_user
    return Tenant.active_context.order(:name).first if current_user.superadmin?

    current_user.accessible_tenants.order(:name).first || Tenant.active_context.order(:name).first
  end
end
