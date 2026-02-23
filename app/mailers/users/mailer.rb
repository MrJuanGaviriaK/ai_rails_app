# frozen_string_literal: true

class Users::Mailer < Devise::Mailer
  layout "mailer"
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "noreply@mail.mrjg.dev")

  def confirmation_instructions(record, token, opts = {})
    super.tap do |message|
      message["List-Unsubscribe"] =
        "<mailto:unsubscribe@mail.mrjg.dev?subject=unsubscribe>"
      message["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    end
  end
end
