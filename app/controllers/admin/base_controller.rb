class Admin::BaseController < ApplicationController
  before_action :require_superadmin!

  private

  def require_superadmin!
    return if current_user&.superadmin?

    redirect_to dashboard_path, alert: "You are not authorized to access this section."
  end
end
