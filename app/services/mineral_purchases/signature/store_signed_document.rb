require "stringio"

module MineralPurchases
  module Signature
    class StoreSignedDocument
      PROCESSING_ERROR_FRAGMENT = "files are still being processed".freeze

      Result = Struct.new(:success?, :error, :retryable, keyword_init: true)

      def self.call(mineral_purchase:, e_signature_request:)
        new(mineral_purchase:, e_signature_request:).call
      end

      def initialize(mineral_purchase:, e_signature_request:)
        @mineral_purchase = mineral_purchase
        @e_signature_request = e_signature_request
      end

      def call
        return Result.new(success?: true, error: nil, retryable: false) if provider_request_id.blank?
        return Result.new(success?: true, error: nil, retryable: false) if already_attached?

        pdf_binary = client.download_signature_request_files(signature_request_id: provider_request_id)

        mineral_purchase.signed_documents.attach(
          io: StringIO.new(pdf_binary),
          filename: document_filename,
          content_type: "application/pdf",
          key: "mineral_purchases/#{mineral_purchase.id}/documents/#{SecureRandom.uuid}-#{document_filename}"
        )

        Result.new(success?: true, error: nil, retryable: false)
      rescue Integrations::DropboxSignClient::Error => e
        Result.new(success?: false, error: e.message, retryable: retryable_error?(e.message))
      end

      private

      attr_reader :mineral_purchase, :e_signature_request

      def provider_request_id
        e_signature_request.provider_signature_request_id.to_s
      end

      def document_filename
        "mineral-purchase-#{mineral_purchase.id}-#{provider_request_id}-signed.pdf"
      end

      def already_attached?
        mineral_purchase.signed_documents.attachments.any? do |attachment|
          attachment.blob.filename.to_s == document_filename
        end
      end

      def client
        @client ||= Integrations::DropboxSignClient.new(e_signature_request.integration)
      end

      def retryable_error?(message)
        message.to_s.downcase.include?(PROCESSING_ERROR_FRAGMENT)
      end
    end
  end
end
