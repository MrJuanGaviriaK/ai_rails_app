class StoreMineralPurchaseSignedDocumentJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 5
  RETRY_DELAY = 20.seconds

  def perform(e_signature_request_id, attempt = 1)
    e_signature_request = ESignatureRequest.includes(:integration, requestable: [ :signed_documents_attachments ]).find_by(id: e_signature_request_id)
    return if e_signature_request.blank?
    return unless e_signature_request.requestable_type == "MineralPurchase"
    return unless e_signature_request.status == "signed"

    mineral_purchase = e_signature_request.requestable
    return if mineral_purchase.blank?

    result = MineralPurchases::Signature::StoreSignedDocument.call(
      mineral_purchase:,
      e_signature_request:
    )

    if result.success?
      clear_failure_reason!(e_signature_request)
      return
    end

    persist_failure_reason!(e_signature_request, result.error)

    return unless result.retryable
    return if attempt >= MAX_ATTEMPTS

    self.class.set(wait: RETRY_DELAY).perform_later(e_signature_request.id, attempt + 1)
  end

  private

  def persist_failure_reason!(e_signature_request, error)
    return if error.blank?

    e_signature_request.update!(failure_reason: error)
  end

  def clear_failure_reason!(e_signature_request)
    return if e_signature_request.failure_reason.blank?

    e_signature_request.update!(failure_reason: nil)
  end
end
