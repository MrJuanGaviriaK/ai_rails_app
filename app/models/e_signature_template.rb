# frozen_string_literal: true

class ESignatureTemplate < ApplicationRecord
  attr_accessor :signer_roles_json, :custom_fields_json, :metadata_json

  belongs_to :integration
  belongs_to :tenant
  has_one_attached :document

  validates :title, presence: true
  validates :provider_template_id, presence: true, uniqueness: { scope: :integration_id }
  validate :document_must_be_pdf
  validate :tenant_matches_integration
  validate :at_least_one_signer_role

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }
  scope :active, -> { where(active: true) }

  before_validation :sync_tenant_from_integration

  private

  def sync_tenant_from_integration
    self.tenant ||= integration&.tenant
  end

  def tenant_matches_integration
    return unless tenant && integration
    return if tenant_id == integration.tenant_id

    errors.add(:tenant_id, :invalid)
  end

  def document_must_be_pdf
    return unless document.attached?
    return if document.content_type == "application/pdf"

    errors.add(:document, :invalid_content_type)
  end

  def at_least_one_signer_role
    roles = Array(signer_roles).filter_map do |role|
      role_name = role.is_a?(Hash) ? role["name"] || role[:name] : role
      role_name.to_s.strip.presence
    end

    return if roles.any?

    errors.add(:signer_roles_json, I18n.t("admin.e_signature_templates.errors.signer_roles_required"))
  end
end
