module DailyPrices
  class Resolver
    Result = Struct.new(:success?, :daily_price, :error, keyword_init: true)

    DEFAULT_TIMEZONE = "America/Bogota".freeze

    def self.call(tenant:, mineral_type:, on_date:)
      new(tenant:, mineral_type:, on_date:).call
    end

    def self.applicable_date_for(tenant:, now: Time.current)
      timezone = resolve_timezone(tenant)
      now.in_time_zone(timezone).to_date
    end

    def self.resolve_timezone(tenant)
      tenant_timezone = tenant&.settings&.fetch("timezone", nil).presence
      return ActiveSupport::TimeZone[tenant_timezone] if tenant_timezone && ActiveSupport::TimeZone[tenant_timezone]

      ActiveSupport::TimeZone[DEFAULT_TIMEZONE]
    end

    def initialize(tenant:, mineral_type:, on_date:)
      @tenant = tenant
      @mineral_type = mineral_type.to_s
      @on_date = on_date
    end

    def call
      daily_price = DailyPrice.approved.find_by(tenant:, mineral_type:, price_date: on_date)
      return Result.new(success?: true, daily_price:, error: nil) if daily_price

      Result.new(success?: false, daily_price: nil, error: :daily_price_not_approved)
    end

    private

    attr_reader :tenant, :mineral_type, :on_date
  end
end
