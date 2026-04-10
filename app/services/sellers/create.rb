module Sellers
  class Create
    Result = Struct.new(:success?, :seller, :errors, keyword_init: true)

    def self.call(actor:, tenant:, attributes:, identification_file:)
      new(actor:, tenant:, attributes:, identification_file:).call
    end

    def initialize(actor:, tenant:, attributes:, identification_file:)
      @actor = actor
      @tenant = tenant
      @attributes = attributes.to_h.symbolize_keys
      @identification_file = identification_file
      @seller = tenant.sellers.new(assignable_attributes)
      @seller.created_by = actor
    end

    def call
      validate_permissions!
      validate_identification_file!
      template = resolve_template

      return failure_result if seller.errors.any?

      ActiveRecord::Base.transaction do
        seller.status = "pending"
        seller.save!
        create_identification_document!
        create_initial_e_signature_request!(template:)
      end

      success_result
    rescue ActiveRecord::RecordInvalid
      failure_result
    end

    private

    attr_reader :actor, :tenant, :attributes, :identification_file, :seller

    def assignable_attributes
      attributes.slice(
        :first_name,
        :last_name,
        :identification_type,
        :identification_number,
        :seller_type,
        :department,
        :city,
        :address,
        :phone,
        :email
      )
    end

    def validate_permissions!
      return if actor&.buyer_for_tenant?(tenant)

      seller.errors.add(:base, I18n.t("admin.sellers.authorization.not_allowed"))
    end

    def validate_identification_file!
      return if identification_file.present?

      seller.errors.add(:base, I18n.t("admin.sellers.errors.identification_required"))
    end

    def resolve_template
      template_id = tenant.seller_habeas_data_template_id
      if template_id.blank?
        seller.errors.add(:base, I18n.t("admin.sellers.errors.template_missing"))
        return nil
      end

      template = tenant.e_signature_templates.find_by(id: template_id)
      if template.blank?
        seller.errors.add(:base, I18n.t("admin.sellers.errors.template_missing"))
        return nil
      end

      template
    end

    def create_identification_document!
      seller_document = seller.seller_documents.new(
        kind: "identification",
        status: "uploaded",
        uploaded_by: actor
      )

      seller_document.file.attach(
        io: identification_file.tempfile,
        filename: identification_file.original_filename,
        content_type: identification_file.content_type,
        key: "sellers/#{seller.id}/identification/#{SecureRandom.uuid}-#{identification_file.original_filename}"
      )

      seller_document.save!
    end

    def create_initial_e_signature_request!(template:)
      seller.e_signature_requests.create!(
        tenant:,
        integration: template.integration,
        initiated_by: actor,
        e_signature_template: template,
        provider: "dropbox_sign",
        status: "draft"
      )
    end

    def success_result
      Result.new(success?: true, seller:, errors: [])
    end

    def failure_result
      Result.new(success?: false, seller:, errors: seller.errors.full_messages)
    end
  end
end
