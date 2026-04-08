class User < ApplicationRecord
  rolify
  after_create :assign_default_role

  has_many :reviewed_tenants, class_name: "Tenant", foreign_key: :reviewed_by_id, inverse_of: :reviewed_by, dependent: :nullify

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

  def superadmin?
    has_role?(:superadmin)
  end

  def accessible_tenants
    return Tenant.active_context if superadmin?

    Tenant.with_role_for_user(self).active_context
  end

  private

  def send_welcome_email
    return unless saved_change_to_confirmed_at?
    return if confirmed_at_before_last_save.present? # only on first confirmation

    UserMailer.welcome_email(self).deliver_later
  end
end
