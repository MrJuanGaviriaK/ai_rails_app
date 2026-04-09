# frozen_string_literal: true

module Api
  module V1
    class IntegrationsController < BaseController
      before_action :set_integration, only: %i[update destroy test_connection]

      def index
        integrations = tenant.integrations.order(:created_at)
        render json: { integrations: integrations.map { |integration| serialize_integration(integration) } }
      end

      def create
        integration = tenant.integrations.new(create_integration_params)

        if integration.save
          render json: { integration: serialize_integration(integration) }, status: :created
        else
          render json: { error: integration.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @integration.assign_attributes(update_integration_params)
        @integration.merge_credentials(credentials_param)

        if @integration.save
          render json: { integration: serialize_integration(@integration) }
        else
          render json: { error: @integration.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @integration.destroy!
        head :no_content
      end

      def test_connection
        result = Integrations::DropboxSignConnectionTester.call(@integration)

        if result.success?
          @integration.update!(status: "active", last_connected_at: Time.current, last_error_message: nil)
          render json: { success: true, account_id: result.account_id, account_name: result.account_name }
        else
          @integration.update!(status: "error", last_error_message: result.error_message)
          render json: { success: false, error: result.error_message }, status: :unprocessable_entity
        end
      end

      private

      def set_integration
        @integration = tenant.integrations.find(params[:id])
      end

      def create_integration_params
        params.require(:integration).permit(
          :name,
          :provider,
          :priority,
          :status,
          credentials: {},
          settings: {},
          provider_config: {}
        )
      end

      def update_integration_params
        params.require(:integration).permit(:name, :priority, :status, settings: {}, provider_config: {})
      end

      def credentials_param
        params.require(:integration).permit(credentials: {}).fetch(:credentials, {})
      end

      def serialize_integration(integration)
        {
          id: integration.id,
          tenant_id: integration.tenant_id,
          name: integration.name,
          provider: integration.provider,
          capabilities: integration.capabilities,
          status: integration.status,
          priority: integration.priority,
          provider_config: integration.provider_config,
          settings: integration.settings,
          last_connected_at: integration.last_connected_at,
          last_error_message: integration.last_error_message,
          has_credentials: integration.has_credentials?,
          public_credentials: integration.masked_credentials
        }
      end
    end
  end
end
