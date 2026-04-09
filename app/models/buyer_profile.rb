class BuyerProfile < ApplicationRecord
  belongs_to :user
  belongs_to :purchasing_location
  belongs_to :created_by, class_name: "User", optional: true

  validates :user_id, uniqueness: true
  validate :purchasing_location_must_be_active_and_kept

  private

  def purchasing_location_must_be_active_and_kept
    return if purchasing_location.blank?
    return if purchasing_location.active? && purchasing_location.deleted_at.nil?

    errors.add(:purchasing_location, :invalid)
  end
end
