class Admin::BaseController < ApplicationController
  before_action :require_superadmin!

  private

  def require_superadmin!
    return if current_user&.superadmin?

    redirect_to dashboard_path, alert: t("admin.authorization.not_allowed")
  end
end
