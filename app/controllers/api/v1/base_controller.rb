# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      before_action :set_api_tenant
      before_action :require_tenant_admin_access!

      private

      attr_reader :tenant

      def set_api_tenant
        @tenant = Current.tenant

        if @tenant.blank?
          render json: { error: I18n.t("api.v1.base.tenant_required") }, status: :unprocessable_entity
          return
        end

        return if params[:tenant].blank?
        return if params[:tenant].to_s == @tenant.slug || params[:tenant].to_s == @tenant.id.to_s

        render json: { error: I18n.t("api.v1.base.tenant_mismatch") }, status: :forbidden
      end

      def require_tenant_admin_access!
        return if current_user&.superadmin?
        return if current_user&.admin_for_tenant?(tenant)

        render json: { error: I18n.t("api.v1.base.not_authorized") }, status: :forbidden
      end
    end
  end
end
