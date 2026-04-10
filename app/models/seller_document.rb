class SellerDocument < ApplicationRecord
  KINDS = %w[identification habeas_data_consent_signed other].freeze
  STATUSES = %w[uploaded verified rejected].freeze
  IDENTIFICATION_ALLOWED_CONTENT_TYPES = [
    "application/pdf",
    "image/png",
    "image/jpeg"
  ].freeze

  belongs_to :seller
  belongs_to :uploaded_by, class_name: "User", optional: true

  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :file_presence
  validate :identification_content_type
  validate :signed_consent_must_be_pdf

  def identification?
    kind == "identification"
  end

  def signed_consent?
    kind == "habeas_data_consent_signed"
  end

  private

  def file_presence
    errors.add(:file, :blank) unless file.attached?
  end

  def identification_content_type
    return unless identification?
    return unless file.attached?
    return if IDENTIFICATION_ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, :invalid_content_type)
  end

  def signed_consent_must_be_pdf
    return unless signed_consent?
    return unless file.attached?
    return if file.content_type == "application/pdf"

    errors.add(:file, :invalid_content_type)
  end
end
