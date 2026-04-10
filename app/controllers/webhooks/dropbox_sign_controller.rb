# frozen_string_literal: true

module Webhooks
  class DropboxSignController < ActionController::API
    CALLBACK_OK_BODY = "Hello API Event Received"

    # POST /webhooks/dropbox_sign
    def receive
      event_data = parse_event_data
      event_type = event_data.dig("event", "event_type").to_s

      Rails.logger.info("[DropboxSign Webhook] Received event: #{event_type}")

      return render plain: CALLBACK_OK_BODY, status: :ok if event_type == "callback_test"

      integration = find_integration(event_data)
      unless integration
        Rails.logger.warn("[DropboxSign Webhook] No integration found for event: #{event_type}")
        return render plain: CALLBACK_OK_BODY, status: :ok
      end

      Integrations::DropboxSign::WebhookService.process(
        integration:,
        event_type:,
        event_data:
      )

      render plain: CALLBACK_OK_BODY, status: :ok
    rescue JSON::ParserError => e
      Rails.logger.error("[DropboxSign Webhook] Invalid JSON payload: #{e.message}")
      render plain: CALLBACK_OK_BODY, status: :ok
    rescue StandardError => e
      Rails.logger.error("[DropboxSign Webhook] Unexpected error: #{e.class} - #{e.message}")
      render plain: CALLBACK_OK_BODY, status: :ok
    end

    private

    def parse_event_data
      if params[:json].present?
        JSON.parse(params[:json])
      else
        params.to_unsafe_h.except("controller", "action")
      end
    end

    def find_integration(event_data)
      request_id = event_data.dig("signature_request", "signature_request_id").to_s
      if request_id.present?
        e_signature_request = ESignatureRequest.find_by(provider_signature_request_id: request_id)
        return e_signature_request.integration if e_signature_request
      end

      template_id = event_data.dig("template", "template_id").to_s
      if template_id.present?
        template = ESignatureTemplate.find_by(provider_template_id: template_id)
        return template.integration if template
      end

      active_dropbox_sign_integrations = Integration.where(provider: "dropbox_sign", status: "active")
      active_dropbox_sign_integrations.first if active_dropbox_sign_integrations.count == 1
    end
  end
end
