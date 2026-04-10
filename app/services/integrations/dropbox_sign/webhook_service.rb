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
          mark_as_awaiting_signature_if_needed!
          complete_seller_request!
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

      def mark_failed_status!(status)
        e_signature_request.update!(
          status:,
          failed_at: Time.current,
          failure_reason: event_type
        )
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
