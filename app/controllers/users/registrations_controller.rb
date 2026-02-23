# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout "devise"

  before_action :configure_sign_up_params, only: [ :create ]

  # Renders the "check your inbox" page — no auth required.
  def check_email
    @email = params[:email]
  end

  private

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
  end

  # Called by Devise after sign-up when the user cannot log in yet (confirmable).
  def after_inactive_sign_up_path_for(resource)
    check_email_users_registrations_path(email: resource.email)
  end
end
