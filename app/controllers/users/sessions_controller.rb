# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout "devise"

  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      sign_in(resource_name, resource)
      redirect_to after_sign_in_path_for(resource), notice: t("devise.sessions.signed_in")
    else
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      flash.now[:alert] = t("devise.failure.invalid", authentication_keys: resource_class.human_attribute_name(:email))
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out(resource_name)
    redirect_to after_sign_out_path_for(resource_name), status: :see_other, notice: t("devise.sessions.signed_out")
  end
end
