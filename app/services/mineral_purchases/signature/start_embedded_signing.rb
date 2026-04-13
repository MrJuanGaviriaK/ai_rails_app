module MineralPurchases
  module Signature
    class StartEmbeddedSigning
      Result = Struct.new(:e_signature_request, :sign_url, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(mineral_purchase:, actor:)
        new(mineral_purchase:, actor:).call
      end

      def initialize(mineral_purchase:, actor:)
        @mineral_purchase = mineral_purchase
        @actor = actor
      end

      def call
        return Result.new(e_signature_request:, sign_url: nil, error: nil) if e_signature_request.signed?

        ensure_provider_signature!
        sign_url_payload = client.embedded_sign_url(signature_id: e_signature_request.provider_signature_id)

        Result.new(e_signature_request:, sign_url: sign_url_payload.fetch("sign_url"), error: nil)
      rescue Integrations::DropboxSignClient::Error => e
        e_signature_request.update(status: "failed", failed_at: Time.current, failure_reason: e.message)
        MineralPurchases::StatusTransitioner.mark_signature_failed!(mineral_purchase)
        Result.new(e_signature_request:, sign_url: nil, error: e.message)
      end

      private

      attr_reader :mineral_purchase, :actor

      def e_signature_request
        @e_signature_request ||= mineral_purchase.e_signature_request || raise(ActiveRecord::RecordNotFound)
      end

      def client
        @client ||= Integrations::DropboxSignClient.new(e_signature_request.integration)
      end

      def ensure_provider_signature!
        return if e_signature_request.provider_signature_id.present?

        response = client.create_embedded_signature_request_with_template(
          template_id: e_signature_request.e_signature_template.provider_template_id,
          signer_name: mineral_purchase.seller.full_name,
          signer_email_address: mineral_purchase.seller.email.presence || "seller-#{mineral_purchase.seller.id}@example.invalid",
          signer_role: signer_role_name,
          custom_fields: custom_fields
        )

        signature_request_payload = response.fetch("signature_request")
        signature_payload = Array(signature_request_payload["signatures"]).first || {}

        e_signature_request.update!(
          provider_signature_request_id: signature_request_payload.fetch("signature_request_id"),
          provider_signature_id: signature_payload.fetch("signature_id"),
          status: "awaiting_signature",
          sent_at: Time.current,
          raw_provider_payload: response
        )

        MineralPurchases::StatusTransitioner.mark_signature_pending!(mineral_purchase)
      end

      def signer_role_name
        template = e_signature_request.e_signature_template
        template.signer_roles.filter_map do |role|
          role = role.to_h if role.respond_to?(:to_h)
          next unless role.is_a?(Hash)

          (role["name"] || role[:name]).to_s.strip.presence
        end.first || "SELLER"
      end

      def custom_fields
        template = e_signature_request.e_signature_template

        template.custom_fields.filter_map do |field|
          field = field.to_h if field.respond_to?(:to_h)
          next unless field.is_a?(Hash)

          name = field["name"].to_s
          next if name.blank?

          { name:, value: merged_value_for(name:) }
        end
      end

      def merged_value_for(name:)
        mapping = {
          "seller_fullname" => mineral_purchase.seller.full_name,
          "seller_identification" => mineral_purchase.seller.identification_number,
          "seller_grams" => format("%.2f", mineral_purchase.fine_grams),
          "seller_total_price" => format("%.2f", mineral_purchase.total_price_cop)
        }

        mapping[name.to_s.strip.downcase] || ""
      end
    end
  end
end
