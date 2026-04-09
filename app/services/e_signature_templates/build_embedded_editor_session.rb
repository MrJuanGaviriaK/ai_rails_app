# frozen_string_literal: true

module ESignatureTemplates
  class BuildEmbeddedEditorSession
    LOCAL_TEMPLATE_PREFIX = "local_"

    def self.call(template:)
      new(template:).call
    end

    def initialize(template:)
      @template = template
      @client = Integrations::DropboxSignClient.new(template.integration)
    end

    def call
      embedded_payload = if requires_new_embedded_template?
        create_embedded_draft!
      else
        fetch_edit_url_or_fallback!
      end

      {
        client_id: @client.client_id,
        edit_url: embedded_payload.fetch("edit_url"),
        skip_domain_verification: @client.test_mode?
      }
    end

    private

    def requires_new_embedded_template?
      @template.provider_template_id.blank? || @template.provider_template_id.start_with?(LOCAL_TEMPLATE_PREFIX)
    end

    def fetch_edit_url_or_fallback!
      @client.embedded_template_edit_url(
        template_id: @template.provider_template_id,
        merge_fields: @template.custom_fields
      )
    rescue Integrations::DropboxSignClient::Error
      raise unless @template.document.attached?

      create_embedded_draft!
    end

    def create_embedded_draft!
      payload = @client.create_embedded_template_draft(template: @template)
      persist_embedded_template_reference!(payload)
      payload
    end

    def persist_embedded_template_reference!(payload)
      remote_template_id = payload["template_id"].to_s
      return if remote_template_id.blank?

      metadata = (@template.metadata || {}).merge("source" => "dropbox_sign_embedded")

      @template.update!(
        provider_template_id: remote_template_id,
        metadata: metadata,
        last_synced_at: Time.current
      )
    end
  end
end
