class Tenant < ApplicationRecord
  resourcify

  STATUSES = %w[active suspended archived].freeze

  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :purchasing_locations, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :status, inclusion: { in: STATUSES }

  before_validation :normalize_slug

  scope :kept, -> { where(deleted_at: nil) }
  scope :active_context, -> { kept.where(status: "active") }

  def self.with_role_for_user(user)
    return none unless user

    joins("INNER JOIN roles ON roles.resource_type = 'Tenant' AND roles.resource_id = tenants.id")
      .joins("INNER JOIN users_roles ON users_roles.role_id = roles.id")
      .where(users_roles: { user_id: user.id })
      .distinct
  end

  def soft_delete!
    update!(deleted_at: Time.current, status: "archived")
  end

  private

  def normalize_slug
    self.slug = slug.presence || name.to_s
    self.slug = slug.to_s.parameterize
  end
end
