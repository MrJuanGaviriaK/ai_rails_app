module Admin
  class DailyPricesController < ApplicationController
    before_action :set_tenant
    before_action :require_daily_price_access!
    before_action :set_daily_price, only: %i[edit update]

    def index
      @state_filter = params[:state].presence_in(DailyPrice::STATES)
      @mineral_filter = params[:mineral_type].to_s.strip.presence
      @price_date_filter = parse_date(params[:price_date])

      @daily_prices = @tenant.daily_prices
        .includes(:created_by, :reviewed_by)
        .with_state(@state_filter)
        .with_mineral_type(@mineral_filter)
        .with_price_date(@price_date_filter)
        .latest_first
    end

    def new
      @daily_price = @tenant.daily_prices.new(price_date: Date.current, state: "pending")
    end

    def create
      @daily_price = @tenant.daily_prices.new(base_daily_price_params)
      @daily_price.created_by = current_user

      ActiveRecord::Base.transaction do
        @daily_price.save!
        apply_state_transition!(@daily_price)
      end

      redirect_to admin_daily_prices_path, notice: t("admin.daily_prices.flash.created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique
      @daily_price.errors.add(:base, t("admin.daily_prices.errors.approved_conflict"))
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      ActiveRecord::Base.transaction do
        @daily_price.assign_attributes(base_daily_price_params)
        @daily_price.save!
        apply_state_transition!(@daily_price)
      end

      redirect_to admin_daily_prices_path, notice: t("admin.daily_prices.flash.updated")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique
      @daily_price.errors.add(:base, t("admin.daily_prices.errors.approved_conflict"))
      render :edit, status: :unprocessable_entity
    end

    private

    def set_tenant
      @tenant = current_tenant
      return if @tenant.present?

      redirect_to dashboard_path, alert: t("admin.daily_prices.authorization.not_allowed")
    end

    def require_daily_price_access!
      return if current_user&.superadmin?
      return if current_user&.admin_for_tenant?(@tenant)

      redirect_to dashboard_path, alert: t("admin.daily_prices.authorization.not_allowed")
    end

    def set_daily_price
      @daily_price = @tenant.daily_prices.find(params[:id])
    end

    def daily_price_params
      params.require(:daily_price).permit(:mineral_type, :price_date, :unit_price_cop, :notes, :state, :rejection_reason)
    end

    def base_daily_price_params
      daily_price_params.slice(:mineral_type, :price_date, :unit_price_cop, :notes)
    end

    def apply_state_transition!(daily_price)
      case selected_state
      when "approved"
        daily_price.approve!(actor: current_user) unless daily_price.approved?
      when "rejected"
        if !daily_price.rejected? || daily_price.rejection_reason != rejection_reason
          daily_price.reject!(actor: current_user, rejection_reason: rejection_reason)
        end
      when "pending"
        daily_price.mark_pending! unless daily_price.pending?
      else
        daily_price.errors.add(:state, :inclusion)
        raise ActiveRecord::RecordInvalid, daily_price
      end
    end

    def selected_state
      daily_price_params[:state].presence || "pending"
    end

    def rejection_reason
      daily_price_params[:rejection_reason].to_s.strip
    end

    def parse_date(value)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
