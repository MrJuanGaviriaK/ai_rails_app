# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  layout "devise"

  def show
    super do |resource|
      if resource.errors.empty?
        set_flash_message!(:notice, :confirmed)
        sign_in(resource_name, resource)
        redirect_to after_sign_in_path_for(resource), status: :see_other and return
      end
    end
  end
end
