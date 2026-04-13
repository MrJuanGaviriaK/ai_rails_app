module ESignatureTemplates
  class ResolveForMineralPurchase
    TARGET_TITLE = "seller_contract_accounts_for_participation_v1".freeze

    Result = Struct.new(:template, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(tenant:)
      new(tenant:).call
    end

    def initialize(tenant:)
      @tenant = tenant
    end

    def call
      all_by_title = tenant.e_signature_templates.where(title: TARGET_TITLE)
      return Result.new(template: nil, error: :template_not_found) if all_by_title.empty?

      active_templates = all_by_title.active
      return Result.new(template: nil, error: :template_inactive) if active_templates.empty?

      templates = tenant
        .e_signature_templates
        .active
        .where(title: TARGET_TITLE)
        .joins(:integration)
        .where(integrations: { provider: "dropbox_sign", status: "active" })
        .includes(:integration)

      return Result.new(template: nil, error: :template_inactive) if templates.empty?
      return Result.new(template: nil, error: :template_ambiguous) if templates.size > 1

      Result.new(template: templates.first, error: nil)
    end

    private

    attr_reader :tenant
  end
end
