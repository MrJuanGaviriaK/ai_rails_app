# frozen_string_literal: true

module ESignatureTemplates
  class UpsertFromProvider
    def self.call(integration:, provider_template:)
      template = integration.e_signature_templates.find_or_initialize_by(
        provider_template_id: provider_template.fetch(:provider_template_id)
      )

      template.assign_attributes(
        tenant: integration.tenant,
        title: provider_template[:title].presence || "Untitled template",
        message: provider_template[:message],
        signer_roles: provider_template[:signer_roles] || [],
        custom_fields: provider_template[:custom_fields] || [],
        metadata: provider_template[:metadata] || {},
        active: provider_template.key?(:active) ? provider_template[:active] : true,
        last_synced_at: provider_template[:last_synced_at] || Time.current
      )

      template.save!
      template
    end
  end
end
