module MineralPurchases
  class RetrySignature
    Result = Struct.new(:success?, :mineral_purchase, :error, keyword_init: true)

    def self.call(actor:, mineral_purchase:)
      new(actor:, mineral_purchase:).call
    end

    def initialize(actor:, mineral_purchase:)
      @actor = actor
      @mineral_purchase = mineral_purchase
    end

    def call
      return failure(I18n.t("admin.mineral_purchases.errors.retry_not_allowed")) unless mineral_purchase.signature_failed?
      return failure(I18n.t("admin.mineral_purchases.authorization.not_allowed")) unless allowed_actor?

      template_result = ESignatureTemplates::ResolveForMineralPurchase.call(tenant: mineral_purchase.tenant)
      return failure(template_error_message(template_result.error)) unless template_result.success?

      ActiveRecord::Base.transaction do
        mineral_purchase.e_signature_request&.destroy!

        mineral_purchase.create_e_signature_request!(
          tenant: mineral_purchase.tenant,
          integration: template_result.template.integration,
          initiated_by: actor,
          e_signature_template: template_result.template,
          provider: "dropbox_sign",
          status: "draft"
        )

        mineral_purchase.update!(status: "created")
      end

      InitiateMineralPurchaseSignatureJob.perform_later(mineral_purchase.id)

      Result.new(success?: true, mineral_purchase:, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :mineral_purchase

    def failure(error)
      Result.new(success?: false, mineral_purchase:, error:)
    end

    def allowed_actor?
      actor&.buyer_for_tenant?(mineral_purchase.tenant) || actor&.admin_for_tenant?(mineral_purchase.tenant)
    end

    def template_error_message(error_key)
      case error_key
      when :template_not_found
        I18n.t("admin.mineral_purchases.errors.template_not_found")
      when :template_inactive
        I18n.t("admin.mineral_purchases.errors.template_inactive")
      when :template_ambiguous
        I18n.t("admin.mineral_purchases.errors.template_ambiguous")
      else
        I18n.t("admin.mineral_purchases.errors.retry_failed")
      end
    end
  end
end
