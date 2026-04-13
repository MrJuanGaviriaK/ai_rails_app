class InitiateMineralPurchaseSignatureJob < ApplicationJob
  queue_as :default

  def perform(mineral_purchase_id)
    mineral_purchase = MineralPurchase.includes(:seller, e_signature_request: [ :e_signature_template, :integration ]).find(mineral_purchase_id)
    e_signature_request = mineral_purchase.e_signature_request
    return if e_signature_request.blank?
    return unless e_signature_request.status == "draft"

    MineralPurchases::StatusTransitioner.mark_signature_pending!(mineral_purchase)

    response = client_for(e_signature_request).create_embedded_signature_request_with_template(
      template_id: e_signature_request.e_signature_template.provider_template_id,
      signer_name: mineral_purchase.seller.full_name,
      signer_email_address: seller_email_for(mineral_purchase.seller),
      signer_role: signer_role_name(e_signature_request.e_signature_template),
      custom_fields: build_custom_fields(mineral_purchase:, template: e_signature_request.e_signature_template)
    )

    signature_request_payload = response.fetch("signature_request")
    signature_payload = Array(signature_request_payload["signatures"]).first || {}

    e_signature_request.update!(
      provider_signature_request_id: signature_request_payload.fetch("signature_request_id"),
      provider_signature_id: signature_payload["signature_id"],
      status: "awaiting_signature",
      sent_at: Time.current,
      raw_provider_payload: response
    )
  rescue Integrations::DropboxSignClient::Error => e
    fail_request!(e_signature_request:, mineral_purchase:, reason: e.message)
  end

  private

  def client_for(e_signature_request)
    Integrations::DropboxSignClient.new(e_signature_request.integration)
  end

  def seller_email_for(seller)
    seller.email.presence || "seller-#{seller.id}@example.invalid"
  end

  def signer_role_name(template)
    template.signer_roles.filter_map do |role|
      role = role.to_h if role.respond_to?(:to_h)
      next unless role.is_a?(Hash)

      name = (role["name"] || role[:name]).to_s.strip
      name.presence
    end.first || "SELLER"
  end

  def build_custom_fields(mineral_purchase:, template:)
    template.custom_fields.filter_map do |field|
      field = field.to_h if field.respond_to?(:to_h)
      next unless field.is_a?(Hash)

      name = field["name"].to_s
      next if name.blank?

      { name:, value: custom_field_value(name:, mineral_purchase:) }
    end
  end

  def custom_field_value(name:, mineral_purchase:)
    seller = mineral_purchase.seller

    mapping = {
      "seller_fullname" => seller.full_name,
      "seller_identification" => seller.identification_number,
      "seller_grams" => format("%.2f", mineral_purchase.fine_grams),
      "seller_total_price" => format("%.2f", mineral_purchase.total_price_cop)
    }

    mapping[name.to_s.strip.downcase] || ""
  end

  def fail_request!(e_signature_request:, mineral_purchase:, reason:)
    return if e_signature_request.blank? || mineral_purchase.blank?

    e_signature_request.update(status: "failed", failed_at: Time.current, failure_reason: reason)
    MineralPurchases::StatusTransitioner.mark_signature_failed!(mineral_purchase)
  end
end
