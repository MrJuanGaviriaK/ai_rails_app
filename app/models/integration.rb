# frozen_string_literal: true

class Integration < ApplicationRecord
  PROVIDERS = %w[dropbox_sign].freeze
  STATUSES = %w[inactive active error].freeze
  PROVIDER_CAPABILITY_MAP = {
    "dropbox_sign" => %w[e_signature]
  }.freeze

  belongs_to :tenant
  has_many :e_signature_templates, dependent: :destroy
  has_many :e_signature_requests, dependent: :restrict_with_error

  validates :name, presence: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }

  before_validation :assign_capabilities

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }

  def has_credentials?
    credentials.present?
  end

  def masked_credentials
    credentials.each_with_object({}) do |(key, value), hash|
      next if value.blank?

      hash[key] = mask_value(value)
    end
  end

  def merge_credentials(new_credentials)
    return if new_credentials.blank?

    self.credentials = credentials.merge(new_credentials)
  end

  private

  def assign_capabilities
    self.capabilities = PROVIDER_CAPABILITY_MAP[provider] || []
  end

  def mask_value(value)
    str = value.to_s
    return "••••••" if str.length <= 6

    "••••••#{str.last(6)}"
  end
end
