# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(
      to: @user.email,
      subject: I18n.t("mailers.user_mailer.welcome_email.subject", name: @user.name),
      "List-Unsubscribe"      => "<mailto:unsubscribe@mail.mrjg.dev?subject=unsubscribe>",
      "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click"
    )
  end
end
