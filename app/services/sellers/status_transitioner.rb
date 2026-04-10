module Sellers
  class StatusTransitioner
    Result = Struct.new(:changed, :status, keyword_init: true)

    def self.call(seller:)
      new(seller:).call
    end

    def initialize(seller:)
      @seller = seller
    end

    def call
      return Result.new(changed: false, status: seller.status) unless seller.pending?
      return Result.new(changed: false, status: seller.status) unless requirements_met?

      seller.update!(status: "in_review")
      Result.new(changed: true, status: seller.status)
    end

    private

    attr_reader :seller

    def requirements_met?
      seller.identification_document.present? && seller.signed_consent_document.present?
    end
  end
end
