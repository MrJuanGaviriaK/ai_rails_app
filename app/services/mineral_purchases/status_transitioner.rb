module MineralPurchases
  class StatusTransitioner
    def self.mark_signature_pending!(mineral_purchase)
      return if mineral_purchase.signature_pending?
      return if mineral_purchase.signature_failed?
      return if mineral_purchase.completed?

      mineral_purchase.update!(status: "signature_pending")
    end

    def self.mark_signature_failed!(mineral_purchase)
      return if mineral_purchase.completed?
      return if mineral_purchase.status == "canceled"

      mineral_purchase.update!(status: "signature_failed")
    end

    def self.complete_if_signed!(mineral_purchase)
      request = mineral_purchase.e_signature_request
      return false unless request&.signed?
      return true if mineral_purchase.completed?

      mineral_purchase.update!(status: "completed", completed_at: Time.current)
      true
    end
  end
end
