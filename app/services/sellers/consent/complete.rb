require "stringio"

module Sellers
  module Consent
    class Complete
      Result = Struct.new(:success?, :e_signature_request, :error, keyword_init: true)

      def self.call(seller:, actor:, request: nil, e_signature_request: nil)
        new(seller:, actor:, request:, e_signature_request:).call
      end

      def initialize(seller:, actor:, request: nil, e_signature_request: nil)
        @seller = seller
        @actor = actor
        @request = request
        @provided_e_signature_request = e_signature_request
      end

      def call
        return Result.new(success?: true, e_signature_request:, error: nil) if e_signature_request.signed?

        if e_signature_request.provider_signature_request_id.blank?
          return Result.new(success?: false, e_signature_request:, error: I18n.t("admin.seller_consents.errors.missing_request"))
        end

        pdf_binary = client.download_signature_request_files(signature_request_id: e_signature_request.provider_signature_request_id)

        ActiveRecord::Base.transaction do
          seller_document = seller.seller_documents.new(
            kind: "habeas_data_consent_signed",
            status: "uploaded",
            uploaded_by: actor
          )

          seller_document.file.attach(
            io: StringIO.new(pdf_binary),
            filename: "habeas-data-signed.pdf",
            content_type: "application/pdf",
            key: "sellers/#{seller.id}/consents/#{SecureRandom.uuid}-habeas-data-signed.pdf"
          )
          seller_document.save!

          e_signature_request.update!(
            status: "signed",
            signed_at: Time.current,
            completed_at: Time.current,
            signed_ip: request&.remote_ip,
            user_agent: request&.user_agent
          )
        end

        Sellers::StatusTransitioner.call(seller:)

        Result.new(success?: true, e_signature_request:, error: nil)
      rescue Integrations::DropboxSignClient::Error => e
        e_signature_request.update(status: "failed", failed_at: Time.current, failure_reason: e.message)
        Result.new(success?: false, e_signature_request:, error: e.message)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, e_signature_request:, error: e.record.errors.full_messages.to_sentence)
      end

      private

      attr_reader :seller, :actor, :request, :provided_e_signature_request

      def e_signature_request
        @e_signature_request ||= provided_e_signature_request || seller.e_signature_requests.latest_first.first!
      end

      def client
        @client ||= Integrations::DropboxSignClient.new(e_signature_request.e_signature_template.integration)
      end
    end
  end
end
