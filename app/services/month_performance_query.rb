# frozen_string_literal: true

# Builds multi-year month-wise relative returns for a single calendar month.
#
# Industry convention: monthly return = (month-end close / prior month-end close) − 1.
# Current year is included only when the target month has fully completed as of `as_of`.
class MonthPerformanceQuery
  DEFAULT_LOOKBACK_YEARS = 10

  def initialize(repository: PriceRepository.new, as_of: Date.current)
    @repository = repository
    @as_of = as_of.to_date
  end

  # @param asset_key [String]
  # @param month [Integer] 1..12
  # @param lookback_years [Integer]
  # @return [Hash] structured result for controllers/views
  def call(asset_key:, month:, lookback_years: DEFAULT_LOOKBACK_YEARS)
    asset = Asset.find!(asset_key)
    month = month.to_i
    raise ArgumentError, "month must be 1..12" unless (1..12).cover?(month)

    lookback_years = lookback_years.to_i
    lookback_years = DEFAULT_LOOKBACK_YEARS if lookback_years <= 0

    years = candidate_years(month, lookback_years)
    points = years.filter_map { |year| build_point(asset.key, year, month) }

    summary = build_summary(points)

    {
      mode: "month",
      asset: asset,
      month: month,
      month_name: Date::MONTHNAMES[month],
      as_of: @as_of,
      lookback_years: lookback_years,
      points: points,
      chart: chart_payload(points),
      summary: summary
    }
  end

  private

  def candidate_years(month, lookback_years)
    current_year = @as_of.year
    include_current = PerformanceCalculator.include_current_year_for_month?(month, as_of: @as_of)

    end_year = include_current ? current_year : current_year - 1
    start_year = end_year - lookback_years + 1
    start_year = [start_year, earliest_available_year].max

    (start_year..end_year).to_a
  end

  def earliest_available_year
    # Conservative floor; actual data presence is checked per year.
    2000
  end

  def build_point(asset_key, year, month)
    return nil unless PerformanceCalculator.month_complete?(year, month, as_of: @as_of)

    start_price = @repository.previous_month_end_close(asset_key, year, month)
    end_price = @repository.month_end_close(asset_key, year, month)
    return_pct = PerformanceCalculator.relative_return_pct(start_price, end_price)
    return nil if return_pct.nil?

    PerformanceCalculator::Result.new(
      year: year,
      month: month,
      return_pct: return_pct,
      start_price: start_price,
      end_price: end_price,
      label: year.to_s,
      complete: true,
      partial: false
    )
  end

  def build_summary(points)
    return empty_summary if points.empty?

    returns = points.map(&:return_pct)
    positive = returns.count(&:positive?)
    negative = returns.count(&:negative?)
    avg = returns.sum / returns.size
    best = points.max_by(&:return_pct)
    worst = points.min_by(&:return_pct)

    {
      count: points.size,
      average_pct: avg,
      median_pct: median(returns),
      positive_years: positive,
      negative_years: negative,
      win_rate_pct: (positive.to_f / points.size) * 100.0,
      best: { year: best.year, return_pct: best.return_pct },
      worst: { year: worst.year, return_pct: worst.return_pct }
    }
  end

  def empty_summary
    {
      count: 0,
      average_pct: nil,
      median_pct: nil,
      positive_years: 0,
      negative_years: 0,
      win_rate_pct: nil,
      best: nil,
      worst: nil
    }
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    if sorted.size.odd?
      sorted[mid]
    else
      (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end

  def chart_payload(points)
    {
      labels: points.map(&:label),
      values: points.map { |p| p.return_pct.round(2) },
      colors: points.map { |p| p.return_pct >= 0 ? "positive" : "negative" }
    }
  end
end
