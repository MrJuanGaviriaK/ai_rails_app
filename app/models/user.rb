class User < ApplicationRecord
  rolify

  has_many :reviewed_tenants, class_name: "Tenant", foreign_key: :reviewed_by_id, inverse_of: :reviewed_by, dependent: :nullify
  has_many :created_sellers, class_name: "Seller", foreign_key: :created_by_id, inverse_of: :created_by
  has_many :reviewed_sellers, class_name: "Seller", foreign_key: :reviewed_by_id, inverse_of: :reviewed_by, dependent: :nullify
  has_many :initiated_e_signature_requests, class_name: "ESignatureRequest", foreign_key: :initiated_by_id, inverse_of: :initiated_by, dependent: :nullify
  has_one :buyer_profile, dependent: :destroy
  has_one :purchasing_location, through: :buyer_profile

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  validates :name, presence: true

  after_commit :send_welcome_email, on: :update

  scope :kept, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }

  def self.with_role_for_tenant(tenant)
    return none unless tenant

    joins(:roles).where(roles: { resource_type: "Tenant", resource_id: tenant.id }).distinct
  end

  def superadmin?
    has_role?(:superadmin)
  end

  def admin_for_tenant?(tenant)
    return false unless tenant

    superadmin? || has_role?(:admin, tenant)
  end

  def buyer_for_tenant?(tenant)
    return false unless tenant

    superadmin? || has_role?(:buyer, tenant)
  end

  def compliance_officer_for_tenant?(tenant)
    return false unless tenant

    superadmin? || has_role?(:compliance_officer, tenant)
  end

  def seller_workflow_access_for_tenant?(tenant)
    admin_for_tenant?(tenant) || buyer_for_tenant?(tenant) || compliance_officer_for_tenant?(tenant)
  end

  def accessible_tenants
    return Tenant.active_context if superadmin?

    Tenant.with_role_for_user(self).active_context
  end

  def archived?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def active_for_authentication?
    super && !archived?
  end

  def inactive_message
    return :archived if archived?

    super
  end

  private

  def send_welcome_email
    return unless saved_change_to_confirmed_at?
    return if confirmed_at_before_last_save.present? # only on first confirmation

    UserMailer.welcome_email(self).deliver_later
  end
end
