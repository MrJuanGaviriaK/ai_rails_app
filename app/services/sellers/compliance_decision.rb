module Sellers
  class ComplianceDecision
    Result = Struct.new(:success?, :seller, :error, keyword_init: true)

    def self.call(seller:, actor:, decision:, rejection_reason: nil)
      new(seller:, actor:, decision:, rejection_reason:).call
    end

    def initialize(seller:, actor:, decision:, rejection_reason: nil)
      @seller = seller
      @actor = actor
      @decision = decision.to_s
      @rejection_reason = rejection_reason.to_s.strip
    end

    def call
      unless seller.in_review?
        return Result.new(success?: false, seller:, error: I18n.t("admin.seller_compliance.errors.invalid_status"))
      end

      unless actor.compliance_officer_for_tenant?(seller.tenant)
        return Result.new(success?: false, seller:, error: I18n.t("admin.seller_compliance.authorization.not_allowed"))
      end

      if rejecting? && rejection_reason.blank?
        return Result.new(success?: false, seller:, error: I18n.t("admin.seller_compliance.errors.rejection_reason_required"))
      end

      attributes = {
        reviewed_by: actor,
        reviewed_at: Time.current,
        status: approving? ? "approved" : "rejected",
        rejection_reason: approving? ? nil : rejection_reason
      }

      seller.update!(attributes)
      Result.new(success?: true, seller:, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, seller:, error: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :seller, :actor, :decision, :rejection_reason

    def approving?
      decision == "approve"
    end

    def rejecting?
      decision == "reject"
    end
  end
end
