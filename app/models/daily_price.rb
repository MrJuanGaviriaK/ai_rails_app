class DailyPrice < ApplicationRecord
  STATES = %w[pending approved rejected].freeze
  MINERAL_TYPES = %w[
    oro
    plata
    platio
  ].freeze

  belongs_to :tenant
  belongs_to :created_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :mineral_purchases, dependent: :nullify

  validates :mineral_type, :price_date, :unit_price_cop, :state, presence: true
  validates :state, inclusion: { in: STATES }
  validates :mineral_type, inclusion: { in: MINERAL_TYPES }
  validates :unit_price_cop, numericality: { greater_than: 0 }
  validates :rejection_reason, presence: true, if: :rejected?

  scope :latest_first, -> { order(price_date: :desc, updated_at: :desc) }
  scope :with_state, ->(state) { where(state:) if state.present? }
  scope :with_mineral_type, ->(mineral_type) { where(mineral_type:) if mineral_type.present? }
  scope :with_price_date, ->(price_date) { where(price_date:) if price_date.present? }
  scope :approved, -> { where(state: "approved") }

  def pending?
    state == "pending"
  end

  def approved?
    state == "approved"
  end

  def rejected?
    state == "rejected"
  end

  def approve!(actor:)
    ensure_transition!(from: %w[pending], to: "approved")

    update!(
      state: "approved",
      reviewed_by: actor,
      approved_at: Time.current,
      rejected_at: nil,
      rejection_reason: nil
    )
  end

  def reject!(actor:, rejection_reason:)
    ensure_transition!(from: %w[pending], to: "rejected")

    update!(
      state: "rejected",
      reviewed_by: actor,
      rejected_at: Time.current,
      approved_at: nil,
      rejection_reason: rejection_reason.to_s.strip
    )
  end

  def mark_pending!
    ensure_transition!(from: %w[rejected], to: "pending")

    update!(
      state: "pending",
      reviewed_by: nil,
      approved_at: nil,
      rejected_at: nil,
      rejection_reason: nil
    )
  end

  private

  def ensure_transition!(from:, to:)
    return if from.include?(state)

    errors.add(:state, :invalid_transition, from: state, to: to)
    raise ActiveRecord::RecordInvalid, self
  end
end
