class Admin::TenantContextsController < Admin::BaseController
  def switch
    tenant = Tenant.active_context.find_by(id: params[:tenant_id])

    unless tenant
      redirect_back fallback_location: dashboard_path, alert: "Selected tenant is unavailable."
      return
    end

    previous_tenant_id = session[:current_tenant_id]
    session[:current_tenant_id] = tenant.id

    Rails.logger.info(
      "tenant_context_switched user_id=#{current_user.id} from_tenant_id=#{previous_tenant_id} to_tenant_id=#{tenant.id}"
    )

    redirect_back fallback_location: dashboard_path, notice: "Switched to #{tenant.name}."
  end
end
