class MineralPurchase < ApplicationRecord
  STATUSES = %w[created signature_pending signature_failed completed canceled].freeze

  belongs_to :tenant
  belongs_to :buyer, class_name: "User"
  belongs_to :seller
  belongs_to :purchasing_location, optional: true

  has_one :e_signature_request, as: :requestable, dependent: :destroy
  has_one_attached :miner_live_photo
  has_many_attached :signed_documents

  validates :mineral_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :fine_grams, numericality: { greater_than: 0 }
  validates :total_price_cop, numericality: { greater_than: 0 }
  validate :seller_must_be_approved
  validate :seller_and_buyer_must_match_tenant
  validate :miner_live_photo_must_be_image

  before_validation :normalize_numeric_fields

  scope :latest_first, -> { order(created_at: :desc) }

  def completed?
    status == "completed"
  end

  def signature_failed?
    status == "signature_failed"
  end

  def signature_pending?
    status == "signature_pending"
  end

  private

  def normalize_numeric_fields
    self.fine_grams = round_half_up(fine_grams)
    self.total_price_cop = round_half_up(total_price_cop)
  end

  def round_half_up(value)
    return value if value.blank?

    BigDecimal(value.to_s).round(2, :half_up)
  end

  def seller_must_be_approved
    return if seller.blank?
    return if seller.approved?

    errors.add(:seller, :invalid)
  end

  def seller_and_buyer_must_match_tenant
    return if tenant.blank?

    errors.add(:seller, :invalid) if seller.present? && seller.tenant_id != tenant_id
    errors.add(:buyer, :invalid) if buyer.present? && !buyer.buyer_for_tenant?(tenant)

    if purchasing_location.present? && purchasing_location.tenant_id != tenant_id
      errors.add(:purchasing_location, :invalid)
    end
  end

  def miner_live_photo_must_be_image
    return unless miner_live_photo.attached?
    return if miner_live_photo.content_type.in?([ "image/png", "image/jpeg", "image/webp" ])

    errors.add(:miner_live_photo, :invalid_content_type)
  end
end
