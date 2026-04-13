class Seller < ApplicationRecord
  STATUSES = %w[pending in_review approved rejected].freeze
  SELLER_TYPES = %w[subsistence_miner mining_title_holder].freeze
  IDENTIFICATION_TYPES = %w[cc ce nit passport].freeze

  belongs_to :tenant
  belongs_to :created_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :seller_documents, dependent: :destroy
  has_many :e_signature_requests, as: :requestable, dependent: :destroy
  has_many :mineral_purchases, dependent: :restrict_with_error

  validates :first_name, :last_name, :identification_type, :identification_number,
    :seller_type, :department, :city, :address, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :seller_type, inclusion: { in: SELLER_TYPES }
  validates :identification_type, inclusion: { in: IDENTIFICATION_TYPES }
  validates :identification_number, uniqueness: { scope: [ :tenant_id, :identification_type ] }
  validates :rejection_reason, presence: true, if: :rejected?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  before_validation :normalize_identification_number

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }
  scope :with_status, ->(status) { where(status: status) if status.present? }
  scope :with_seller_type, ->(seller_type) { where(seller_type:) if seller_type.present? }
  scope :search, ->(query) do
    if query.present?
      pattern = "%#{sanitize_sql_like(query.strip)}%"
      where(
        "first_name ILIKE :pattern OR last_name ILIKE :pattern OR identification_number ILIKE :pattern",
        pattern:
      )
    end
  end

  def pending?
    status == "pending"
  end

  def in_review?
    status == "in_review"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  def identification_document
    seller_documents.find_by(kind: "identification")
  end

  def signed_consent_document
    seller_documents.find_by(kind: "habeas_data_consent_signed")
  end

  def signed_consent?
    e_signature_requests.where(status: "signed").exists?
  end

  private

  def normalize_identification_number
    normalized = identification_number.to_s.gsub(/[^0-9A-Za-z]/, "")
    self.identification_number = normalized.upcase
  end
end
