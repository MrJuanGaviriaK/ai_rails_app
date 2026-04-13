module ApplicationHelper
  COLOMBIA_TIME_ZONE = "America/Bogota".freeze

  def format_in_colombia_time(datetime)
    return "—" if datetime.blank?

    localized = datetime.in_time_zone(COLOMBIA_TIME_ZONE)
    "#{I18n.l(localized, format: :long)} (COT)"
  end
end
