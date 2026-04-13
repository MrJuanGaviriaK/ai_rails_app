module MineralPurchases
  module Signature
    class Complete
      Result = Struct.new(:success?, :e_signature_request, :error, keyword_init: true)

      def self.call(mineral_purchase:, actor:, request: nil)
        new(mineral_purchase:, actor:, request:).call
      end

      def initialize(mineral_purchase:, actor:, request: nil)
        @mineral_purchase = mineral_purchase
        @actor = actor
        @request = request
      end

      def call
        unless e_signature_request.signed?
          e_signature_request.update!(
            status: "signed",
            signed_at: Time.current,
            completed_at: Time.current,
            signed_ip: request&.remote_ip,
            user_agent: request&.user_agent
          )
        end

        store_result = store_signed_document!

        if store_result.success?
          clear_failure_reason_if_present!
        else
          persist_failure_reason_if_blank!(store_result.error)
          enqueue_retry_if_needed!(store_result)
        end

        MineralPurchases::StatusTransitioner.complete_if_signed!(mineral_purchase)

        Result.new(success?: true, e_signature_request:, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, e_signature_request:, error: e.record.errors.full_messages.to_sentence)
      end

      private

      attr_reader :mineral_purchase, :actor, :request

      def e_signature_request
        @e_signature_request ||= mineral_purchase.e_signature_request || raise(ActiveRecord::RecordNotFound)
      end

      def store_signed_document!
        MineralPurchases::Signature::StoreSignedDocument.call(
          mineral_purchase:,
          e_signature_request:
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

      def enqueue_retry_if_needed!(store_result)
        return unless store_result.retryable

        StoreMineralPurchaseSignedDocumentJob.perform_later(e_signature_request.id)
      end
    end
  end
end
