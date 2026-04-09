# frozen_string_literal: true

module Api
  module V1
    class ESignatureTemplatesController < BaseController
      before_action :set_template, only: %i[update destroy]

      def index
        templates = scoped_templates.order(updated_at: :desc)
        render json: { templates: templates.map { |template| serialize_template(template) } }
      end

      def create
        integration = tenant.integrations.find(template_params[:integration_id])
        template = integration.e_signature_templates.new(build_template_attributes)

        if template.save
          render json: { template: serialize_template(template) }, status: :created
        else
          render json: { error: template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @template.update(update_template_params)
          render json: { template: serialize_template(@template) }
        else
          render json: { error: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @template.destroy!
        head :no_content
      end

      def sync
        integration = tenant.integrations.find(params.require(:integration_id))
        templates = Integrations::DropboxSignClient.new(integration).list_templates
        synced = templates.count do |provider_template|
          ESignatureTemplates::UpsertFromProvider.call(integration: integration, provider_template: provider_template)
        end

        refreshed_templates = tenant.e_signature_templates
          .where(integration_id: integration.id)
          .includes(:integration)
          .order(updated_at: :desc)

        render json: {
          success: true,
          synced: synced,
          templates: refreshed_templates.map { |template| serialize_template(template) }
        }
      rescue Integrations::DropboxSignClient::Error => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end

      private

      def set_template
        @template = tenant.e_signature_templates.find(params[:id])
      end

      def scoped_templates
        scope = tenant.e_signature_templates.includes(:integration)
        return scope if params[:integration_id].blank?

        scope.where(integration_id: params[:integration_id])
      end

      def template_params
        permitted = params.require(:e_signature_template).permit(
          :integration_id,
          :title,
          :message,
          :provider_template_id,
          :active
        ).to_h.symbolize_keys

        permitted[:signer_roles] = params.dig(:e_signature_template, :signer_roles) if params.dig(:e_signature_template, :signer_roles).present?
        permitted[:custom_fields] = params.dig(:e_signature_template, :custom_fields) if params.dig(:e_signature_template, :custom_fields).present?
        permitted[:metadata] = params.dig(:e_signature_template, :metadata) if params.dig(:e_signature_template, :metadata).present?
        permitted
      end

      def build_template_attributes
        attrs = template_params.except(:integration_id)
        attrs[:tenant_id] = tenant.id
        attrs[:provider_template_id] = attrs[:provider_template_id].presence || "local_#{SecureRandom.uuid}"
        attrs
      end

      def update_template_params
        template_params.except(:integration_id, :provider_template_id)
      end

      def serialize_template(template)
        {
          id: template.id,
          tenant_id: template.tenant_id,
          integration_id: template.integration_id,
          title: template.title,
          message: template.message,
          provider_template_id: template.provider_template_id,
          signer_roles: template.signer_roles,
          custom_fields: template.custom_fields,
          metadata: template.metadata,
          active: template.active,
          last_synced_at: template.last_synced_at,
          created_at: template.created_at,
          updated_at: template.updated_at
        }
      end
    end
  end
end
