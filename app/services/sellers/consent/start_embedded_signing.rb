module Sellers
  module Consent
    class StartEmbeddedSigning
      Result = Struct.new(:e_signature_request, :sign_url, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(seller:, actor:)
        new(seller:, actor:).call
      end

      def initialize(seller:, actor:)
        @seller = seller
        @actor = actor
      end

      def call
        return Result.new(e_signature_request:, sign_url: nil, error: nil) if e_signature_request.signed?

        response = client.create_embedded_signature_request_with_template(
          template_id: e_signature_request.e_signature_template.provider_template_id,
          signer_name: seller.full_name,
          signer_email_address: seller.email.presence || fallback_email,
          signer_role: signer_role_name,
          custom_fields: build_custom_fields
        )

        signature = response.fetch("signature_request").fetch("signatures").first
        sign_url_payload = client.embedded_sign_url(signature_id: signature.fetch("signature_id"))

        e_signature_request.update!(
          provider_signature_request_id: response.fetch("signature_request").fetch("signature_request_id"),
          provider_signature_id: signature.fetch("signature_id"),
          status: "awaiting_signature",
          sent_at: Time.current,
          raw_provider_payload: response
        )

        Result.new(e_signature_request:, sign_url: sign_url_payload.fetch("sign_url"), error: nil)
      rescue Integrations::DropboxSignClient::Error => e
        e_signature_request.update(status: "failed", failed_at: Time.current, failure_reason: e.message)
        Result.new(e_signature_request:, sign_url: nil, error: e.message)
      end

      private

      attr_reader :seller, :actor

      def e_signature_request
        @e_signature_request ||= seller.e_signature_requests.latest_first.first!
      end

      def template
        e_signature_request.e_signature_template
      end

      def integration
        template.integration
      end

      def client
        @client ||= Integrations::DropboxSignClient.new(integration)
      end

      def fallback_email
        "seller-#{seller.id}@example.invalid"
      end

      def signer_role_name
        template.signer_roles.filter_map do |role|
          role = role.to_h if role.respond_to?(:to_h)
          next unless role.is_a?(Hash)

          name = (role["name"] || role[:name]).to_s.strip
          name.presence
        end.first || "seller"
      end

      def build_custom_fields
        template.custom_fields.filter_map do |field|
          field = field.to_h if field.respond_to?(:to_h)
          next unless field.is_a?(Hash)

          name = field["name"].to_s
          next if name.blank?

          {
            name:,
            value: merged_value_for(name:)
          }
        end
      end

      def merged_value_for(name:)
        mapping = {
          "seller_fullname" => seller.full_name,
          "seller_identification" => seller.identification_number,
          "seller_first_name" => seller.first_name,
          "seller_last_name" => seller.last_name,
          "seller_identification_type" => seller.identification_type,
          "seller_identification_number" => seller.identification_number,
          "seller_city" => seller.city,
          "seller_department" => seller.department,
          "seller_address" => seller.address
        }

        mapping[normalize_field_name(name)] || ""
      end

      def normalize_field_name(name)
        name.to_s.strip.downcase
      end
    end
  end
end
