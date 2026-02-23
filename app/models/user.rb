class User < ApplicationRecord
  rolify
  after_create :assign_default_role

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  validates :name, presence: true

  after_commit :send_welcome_email, on: :update

  def assign_default_role
    add_role(:normal_user) if roles.blank?
  end

  private

  def send_welcome_email
    return unless saved_change_to_confirmed_at?
    return if confirmed_at_before_last_save.present? # only on first confirmation

    UserMailer.welcome_email(self).deliver_later
  end
end
