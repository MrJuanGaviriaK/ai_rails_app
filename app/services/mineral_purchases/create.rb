module MineralPurchases
  class Create
    Result = Struct.new(:success?, :mineral_purchase, :errors, keyword_init: true)

    TEMPLATE_ERROR_MAP = {
      template_not_found: "admin.mineral_purchases.errors.template_not_found",
      template_inactive: "admin.mineral_purchases.errors.template_inactive",
      template_ambiguous: "admin.mineral_purchases.errors.template_ambiguous"
    }.freeze

    def self.call(actor:, tenant:, attributes:)
      new(actor:, tenant:, attributes:).call
    end

    def initialize(actor:, tenant:, attributes:)
      @actor = actor
      @tenant = tenant
      @attributes = attributes.to_h.symbolize_keys
      @mineral_purchase = tenant.mineral_purchases.new(assignable_attributes)
      @miner_live_photo_signed_id = @attributes[:miner_live_photo_signed_id].presence
      @mineral_purchase.buyer = actor
      @mineral_purchase.purchasing_location ||= actor.purchasing_location
    end

    def call
      validate_permissions!
      validate_miner_live_photo_presence!
      template_result = resolve_template

      return failure_result if mineral_purchase.errors.any?

      ActiveRecord::Base.transaction do
        mineral_purchase.save!
        attach_miner_live_photo!
        mineral_purchase.create_e_signature_request!(
          tenant:,
          integration: template_result.template.integration,
          initiated_by: actor,
          e_signature_template: template_result.template,
          provider: "dropbox_sign",
          status: "draft"
        )
      end

      InitiateMineralPurchaseSignatureJob.perform_later(mineral_purchase.id)

      success_result
    rescue ActiveRecord::RecordInvalid
      failure_result
    end

    private

    attr_reader :actor, :tenant, :attributes, :mineral_purchase

    def assignable_attributes
      attributes.slice(:seller_id, :mineral_type, :fine_grams, :total_price_cop, :purchasing_location_id)
    end

    def validate_miner_live_photo_presence!
      return if miner_live_photo_signed_id.present?

      mineral_purchase.errors.add(:miner_live_photo, :blank)
    end

    def validate_permissions!
      return if actor&.buyer_for_tenant?(tenant)

      mineral_purchase.errors.add(:base, I18n.t("admin.mineral_purchases.authorization.buyer_required"))
    end

    def resolve_template
      result = ESignatureTemplates::ResolveForMineralPurchase.call(tenant:)
      return result if result.success?

      translation_key = TEMPLATE_ERROR_MAP.fetch(result.error)
      mineral_purchase.errors.add(:base, I18n.t(translation_key))
      result
    end

    def attach_miner_live_photo!
      blob = ActiveStorage::Blob.find_signed!(miner_live_photo_signed_id)
      unless blob.content_type.in?([ "image/png", "image/jpeg", "image/webp" ])
        mineral_purchase.errors.add(:miner_live_photo, :invalid_content_type)
        raise ActiveRecord::RecordInvalid, mineral_purchase
      end

      mineral_purchase.miner_live_photo.attach(blob)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      mineral_purchase.errors.add(:miner_live_photo, :invalid)
      raise ActiveRecord::RecordInvalid, mineral_purchase
    end

    def miner_live_photo_signed_id
      @miner_live_photo_signed_id
    end

    def success_result
      Result.new(success?: true, mineral_purchase:, errors: [])
    end

    def failure_result
      Result.new(success?: false, mineral_purchase:, errors: mineral_purchase.errors.full_messages)
    end
  end
end
