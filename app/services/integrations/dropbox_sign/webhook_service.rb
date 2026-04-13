# frozen_string_literal: true

module Integrations
  module DropboxSign
    class WebhookService
      SIGNED_EVENT_TYPES = %w[signature_request_signed signature_request_all_signed].freeze
      DECLINED_EVENT_TYPES = %w[signature_request_declined].freeze
      CANCELED_EVENT_TYPES = %w[signature_request_canceled].freeze
      EXPIRED_EVENT_TYPES = %w[signature_request_expired].freeze

      def self.process(integration:, event_type:, event_data:)
        new(integration:, event_type:, event_data:).process
      end

      def initialize(integration:, event_type:, event_data:)
        @integration = integration
        @event_type = event_type.to_s
        @event_data = event_data
      end

      def process
        return unless e_signature_request

        update_raw_payload!

        if signed_event?
          process_signed_event!
        elsif declined_event?
          mark_failed_status!("declined")
        elsif canceled_event?
          mark_failed_status!("canceled")
        elsif expired_event?
          mark_failed_status!("expired")
        end
      end

      private

      attr_reader :integration, :event_type, :event_data

      def e_signature_request
        @e_signature_request ||= resolve_e_signature_request
      end

      def resolve_e_signature_request
        request_id = event_data.dig("signature_request", "signature_request_id").to_s
        return nil if request_id.blank?

        integration.e_signature_requests.find_by(provider_signature_request_id: request_id)
      end

      def update_raw_payload!
        payload = e_signature_request.raw_provider_payload.to_h
        events = Array(payload["webhook_events"])
        events << {
          "event_type" => event_type,
          "received_at" => Time.current.iso8601,
          "payload" => event_data
        }

        e_signature_request.update!(raw_provider_payload: payload.merge("webhook_events" => events))
      end

      def mark_as_awaiting_signature_if_needed!
        return if e_signature_request.status == "signed"
        return if e_signature_request.status == "awaiting_signature"

        e_signature_request.update!(status: "awaiting_signature")
      end

      def complete_seller_request!
        return unless e_signature_request.requestable_type == "Seller"

        Sellers::Consent::Complete.call(
          seller: e_signature_request.requestable,
          actor: nil,
          e_signature_request:
        )
      end

      def complete_mineral_purchase_request!
        return unless e_signature_request.requestable_type == "MineralPurchase"

        mark_mineral_purchase_request_as_signed! unless e_signature_request.status == "signed"

        store_result = MineralPurchases::Signature::StoreSignedDocument.call(
          mineral_purchase: e_signature_request.requestable,
          e_signature_request:
        )

        if store_result.success?
          clear_failure_reason_if_present!
        else
          persist_failure_reason_if_blank!(store_result.error)
          enqueue_document_retry_if_needed!(store_result)
        end

        MineralPurchases::StatusTransitioner.complete_if_signed!(e_signature_request.requestable)
      end

      def mark_mineral_purchase_request_as_signed!
        signed_signature = Array(event_data.dig("signature_request", "signatures")).find do |signature|
          signature["status_code"] == "signed"
        end

        e_signature_request.update!(
          status: "signed",
          signed_at: Time.current,
          completed_at: Time.current,
          signed_ip: signed_signature&.dig("signed_ip"),
          user_agent: signed_signature&.dig("user_agent")
        )
      end

      def persist_failure_reason_if_blank!(error)
        return if error.blank? || e_signature_request.failure_reason.present?

        e_signature_request.update!(failure_reason: error)
      end

      def clear_failure_reason_if_present!
        return if e_signature_request.failure_reason.blank?

        e_signature_request.update!(failure_reason: nil)
      end

      def enqueue_document_retry_if_needed!(store_result)
        return unless store_result.retryable

        StoreMineralPurchaseSignedDocumentJob.perform_later(e_signature_request.id)
      end

      def process_signed_event!
        if e_signature_request.requestable_type == "Seller"
          mark_as_awaiting_signature_if_needed!
          complete_seller_request!
        else
          complete_mineral_purchase_request!
        end
      end

      def mark_failed_status!(status)
        return if e_signature_request.status == status

        e_signature_request.update!(
          status:,
          failed_at: Time.current,
          failure_reason: event_type
        )

        return unless e_signature_request.requestable_type == "MineralPurchase"

        MineralPurchases::StatusTransitioner.mark_signature_failed!(e_signature_request.requestable)
      end

      def signed_event?
        SIGNED_EVENT_TYPES.include?(event_type)
      end

      def declined_event?
        DECLINED_EVENT_TYPES.include?(event_type)
      end

      def canceled_event?
        CANCELED_EVENT_TYPES.include?(event_type)
      end

      def expired_event?
        EXPIRED_EVENT_TYPES.include?(event_type)
      end
    end
  end
end
