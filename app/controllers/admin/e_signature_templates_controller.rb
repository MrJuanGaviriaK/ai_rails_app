# frozen_string_literal: true

module Admin
  class ESignatureTemplatesController < ApplicationController
    before_action :set_admin_tenant
    before_action :require_integration_access!
    before_action :set_template, only: %i[edit update destroy builder builder_saved]
    before_action :set_integrations, only: %i[index new create edit update]

    def index
      @templates = scoped_templates.order(updated_at: :desc)
    end

    def new
      @template = @tenant.e_signature_templates.new(active: true)
      @template.integration = @integrations.first
    end

    def create
      integration = @integrations.find_by(id: template_params[:integration_id])
      @template = integration&.e_signature_templates&.new(assignable_template_attributes)
      if missing_document?(@template)
        @template.errors.add(:document, :blank)
        flash.now[:alert] = t("admin.e_signature_templates.flash.fix_errors")
        return render :new, status: :unprocessable_entity
      end

      if @template&.save
        redirect_to builder_admin_e_signature_template_path(@template), notice: t("admin.e_signature_templates.flash.created")
      else
        @template ||= @tenant.e_signature_templates.new
        flash.now[:alert] = t("admin.e_signature_templates.flash.fix_errors")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @template.assign_attributes(assignable_template_attributes)
      if missing_document?(@template)
        @template.errors.add(:document, :blank)
        flash.now[:alert] = t("admin.e_signature_templates.flash.fix_errors")
        return render :edit, status: :unprocessable_entity
      end

      if @template.save
        redirect_to admin_e_signature_templates_path(integration_id: @template.integration_id), notice: t("admin.e_signature_templates.flash.updated")
      else
        flash.now[:alert] = t("admin.e_signature_templates.flash.fix_errors")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      integration_id = @template.integration_id
      @template.destroy!
      redirect_to admin_e_signature_templates_path(integration_id: integration_id), notice: t("admin.e_signature_templates.flash.deleted")
    end

    def builder
      @embedded_session = ESignatureTemplates::BuildEmbeddedEditorSession.call(template: @template)
    rescue Integrations::DropboxSignClient::Error => e
      redirect_to edit_admin_e_signature_template_path(@template), alert: t("admin.e_signature_templates.flash.builder_error", error: e.message)
    end

    def builder_saved
      redirect_to admin_e_signature_templates_path(integration_id: @template.integration_id), notice: t("admin.e_signature_templates.flash.saved")
    end

    private

    def set_admin_tenant
      @tenant = Current.tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.integrations.authorization.not_allowed")
    end

    def require_integration_access!
      return if current_user&.superadmin?
      return if current_user&.admin_for_tenant?(@tenant)

      redirect_to dashboard_path, alert: t("admin.integrations.authorization.not_allowed")
    end

    def set_template
      @template = @tenant.e_signature_templates.includes(:integration).find(params[:id])
    end

    def set_integrations
      @integrations = @tenant.integrations.order(:name)
    end

    def scoped_templates
      scope = @tenant.e_signature_templates.includes(:integration)
      return scope if params[:integration_id].blank?

      scope.where(integration_id: params[:integration_id])
    end

    def template_params
      params.require(:e_signature_template).permit(
        :integration_id,
        :title,
        :message,
        :active,
        :provider_template_id,
        :document,
        :signer_roles_json,
        :custom_fields_json,
        :metadata_json,
        signer_roles_list: [ :name ],
        custom_fields_list: [ :name, :default_value, :signer_role ]
      )
    end

    def assignable_template_attributes
      attrs = template_params.except(
        :integration_id,
        :signer_roles_json,
        :custom_fields_json,
        :metadata_json,
        :signer_roles_list,
        :custom_fields_list
      ).to_h
      attrs["provider_template_id"] = attrs["provider_template_id"].presence || "local_#{SecureRandom.uuid}"
      attrs["signer_roles"] = extract_signer_roles
      attrs["custom_fields"] = extract_custom_fields
      attrs["metadata"] = parse_json_field(:metadata_json, default: {})
      attrs
    end

    def extract_signer_roles
      if template_params[:signer_roles_list].present?
        normalize_signer_roles(template_params[:signer_roles_list])
      else
        normalize_signer_roles(parse_json_field(:signer_roles_json, default: []))
      end
    end

    def normalize_signer_roles(raw_roles)
      roles = normalize_list_input(raw_roles)
      names = roles.filter_map do |role|
        role = role.to_h if role.respond_to?(:to_h)

        name = if role.is_a?(Hash)
                 role["name"] || role[:name]
        else
                 role
        end

        next if name.blank?

        name.to_s.strip
      end

      names.each_with_index.map do |name, index|
        { "name" => name, "order" => index }
      end
    end

    def extract_custom_fields
      if template_params[:custom_fields_list].present?
        normalize_custom_fields(template_params[:custom_fields_list])
      else
        normalize_custom_fields(parse_json_field(:custom_fields_json, default: []))
      end
    end

    def normalize_custom_fields(raw_fields)
      normalize_list_input(raw_fields).filter_map do |field|
        field = field.to_h.stringify_keys if field.respond_to?(:to_h)
        next unless field.is_a?(Hash)

        name = (field["name"] || field["api_id"]).to_s.strip
        default_value = (field["default_value"] || field["value"]).to_s.strip
        signer_role = (field["signer_role"] || field["role"]).to_s.strip
        next if name.blank?

        custom_field = { "name" => name }
        custom_field["default_value"] = default_value if default_value.present?
        custom_field["signer_role"] = signer_role if signer_role.present?
        custom_field
      end
    end

    def normalize_list_input(raw_list)
      return raw_list.to_unsafe_h.values if raw_list.respond_to?(:to_unsafe_h)
      return raw_list.to_h.values if raw_list.respond_to?(:to_h) && raw_list.is_a?(Hash)

      Array(raw_list)
    end

    def parse_json_field(key, default:)
      raw = template_params[key]
      return default if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      @template ||= @tenant.e_signature_templates.new
      @template.errors.add(key, t("admin.e_signature_templates.errors.invalid_json"))
      default
    end

    def missing_document?(template)
      template.present? && !template.document.attached?
    end
  end
end
