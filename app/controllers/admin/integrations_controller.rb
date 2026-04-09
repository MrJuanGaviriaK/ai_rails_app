# frozen_string_literal: true

module Admin
  class IntegrationsController < ApplicationController
    before_action :set_admin_tenant
    before_action :require_integration_access!

    # GET /admin/integrations
    def index
      @integrations = Integration.where(tenant_id: @tenant.id).order(:created_at)
    end

    private

    def set_admin_tenant
      @tenant = Current.tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.integrations.authorization.not_allowed")
    end

    def require_integration_access!
      return if current_user&.superadmin?
      return if current_user&.admin_for_tenant?(@tenant)

      redirect_to dashboard_path, alert: t("admin.integrations.authorization.not_allowed")
    end
  end
end
