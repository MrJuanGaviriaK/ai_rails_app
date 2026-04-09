module Admin
  module Users
    class Provision
      Result = Struct.new(
        :success?,
        :user,
        :selected_role,
        :selected_tenant_id,
        :selected_purchasing_location_id,
        keyword_init: true
      )

      ROLES = %w[superadmin admin buyer client].freeze
      ADMIN_CREATABLE_ROLES = %w[admin buyer client].freeze

      def self.call(actor:, current_tenant:, attributes:)
        new(actor:, current_tenant:, attributes:).call
      end

      def initialize(actor:, current_tenant:, attributes:)
        @actor = actor
        @current_tenant = current_tenant
        @attributes = attributes.to_h.symbolize_keys
        @user = User.new(base_user_attributes)
      end

      def call
        validate_permissions!
        validate_role!
        validate_tenant!
        validate_buyer_location!

        return failure_result unless user.errors.empty?

        ActiveRecord::Base.transaction do
          user.save!
          assign_role!
          create_buyer_profile_if_needed!
        end

        success_result
      rescue ActiveRecord::RecordInvalid
        failure_result
      end

      private

      attr_reader :actor, :current_tenant, :attributes, :user

      def base_user_attributes
        attributes.slice(:name, :email, :password, :password_confirmation)
      end

      def selected_role
        attributes[:role].to_s
      end

      def selected_tenant_id
        if actor.superadmin?
          attributes[:tenant_id].presence&.to_i
        else
          current_tenant&.id
        end
      end

      def selected_purchasing_location_id
        attributes[:purchasing_location_id].presence&.to_i
      end

      def selected_tenant
        return nil if selected_tenant_id.blank?

        @selected_tenant ||= Tenant.active_context.find_by(id: selected_tenant_id)
      end

      def selected_purchasing_location
        return nil if selected_purchasing_location_id.blank?

        @selected_purchasing_location ||= PurchasingLocation
          .kept
          .where(active: true)
          .find_by(id: selected_purchasing_location_id)
      end

      def validate_permissions!
        return if actor.superadmin?
        return if actor.admin_for_tenant?(current_tenant)

        user.errors.add(:base, I18n.t("admin.users.authorization.not_allowed"))
      end

      def validate_role!
        if selected_role.blank?
          user.errors.add(:base, I18n.t("admin.users.errors.role_required"))
          return
        end

        unless ROLES.include?(selected_role)
          user.errors.add(:base, I18n.t("admin.users.errors.invalid_role"))
          return
        end

        if actor.superadmin?
          return
        end

        return if ADMIN_CREATABLE_ROLES.include?(selected_role)

        user.errors.add(:base, I18n.t("admin.users.errors.role_not_allowed"))
      end

      def validate_tenant!
        return if selected_role == "superadmin"

        if selected_tenant.blank?
          user.errors.add(:base, I18n.t("admin.users.errors.tenant_required"))
          nil
        end
      end

      def validate_buyer_location!
        return unless selected_role == "buyer"

        if selected_purchasing_location.blank?
          user.errors.add(:base, I18n.t("admin.users.errors.purchasing_location_required"))
          return
        end

        return if selected_purchasing_location.tenant_id == selected_tenant&.id

        user.errors.add(:base, I18n.t("admin.users.errors.purchasing_location_out_of_scope"))
      end

      def assign_role!
        return user.add_role(:superadmin) if selected_role == "superadmin"

        user.add_role(selected_role.to_sym, selected_tenant)
      end

      def create_buyer_profile_if_needed!
        return unless selected_role == "buyer"

        user.create_buyer_profile!(
          purchasing_location: selected_purchasing_location,
          created_by: actor
        )
      end

      def success_result
        Result.new(
          success?: true,
          user: user,
          selected_role: selected_role,
          selected_tenant_id: selected_tenant_id,
          selected_purchasing_location_id: selected_purchasing_location_id
        )
      end

      def failure_result
        Result.new(
          success?: false,
          user: user,
          selected_role: selected_role,
          selected_tenant_id: selected_tenant_id,
          selected_purchasing_location_id: selected_purchasing_location_id
        )
      end
    end
  end
end
