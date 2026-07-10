# frozen_string_literal: true

# Pure relative-return math and period-completion rules.
# All methods are side-effect free and accept an explicit as_of date for testability.
class PerformanceCalculator
  Result = Data.define(
    :year,
    :month,
    :return_pct,
    :start_price,
    :end_price,
    :label,
    :complete,
    :partial
  )

  class << self
    # Relative return as percentage: (end/start - 1) * 100
    def relative_return_pct(start_price, end_price)
      return nil if start_price.nil? || end_price.nil?
      return nil if start_price.to_f.zero?

      ((end_price.to_f / start_price.to_f) - 1.0) * 100.0
    end

    # A calendar month is complete when as_of is strictly after that month's last day.
    def month_complete?(year, month, as_of:)
      as_of = as_of.to_date
      Date.new(year, month, -1) < as_of
    end

    # A calendar year is complete when as_of is strictly after Dec 31 of that year.
    def year_complete?(year, as_of:)
      as_of = as_of.to_date
      Date.new(year, 12, 31) < as_of
    end

    # Whether the current calendar year has finished the given month.
    def include_current_year_for_month?(month, as_of:)
      as_of = as_of.to_date
      month_complete?(as_of.year, month, as_of: as_of)
    end

    def format_signed_pct(value, precision: 2)
      return "—" if value.nil?

      rounded = value.round(precision)
      sign = rounded.positive? ? "+" : ""
      "#{sign}#{format("%.#{precision}f", rounded)}%"
    end
  end
end
