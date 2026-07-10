# frozen_string_literal: true

# Builds multi-year full-year relative returns.
#
# Industry convention: calendar-year return = (Dec close / prior Dec close) − 1.
# Incomplete current year is returned as YTD when include_ytd is true (default),
# clearly labeled and flagged as partial.
class YearPerformanceQuery
  DEFAULT_LOOKBACK_YEARS = 10

  def initialize(repository: PriceRepository.new, as_of: Date.current)
    @repository = repository
    @as_of = as_of.to_date
  end

  def call(asset_key:, lookback_years: DEFAULT_LOOKBACK_YEARS, include_ytd: true)
    asset = Asset.find!(asset_key)
    lookback_years = lookback_years.to_i
    lookback_years = DEFAULT_LOOKBACK_YEARS if lookback_years <= 0

    years = candidate_years(lookback_years, include_ytd)
    points = years.filter_map { |year| build_point(asset.key, year, include_ytd) }

    summary = build_summary(points.reject(&:partial))

    {
      mode: "year",
      asset: asset,
      as_of: @as_of,
      lookback_years: lookback_years,
      include_ytd: include_ytd,
      points: points,
      chart: chart_payload(points),
      summary: summary
    }
  end

  private

  def candidate_years(lookback_years, include_ytd)
    current_year = @as_of.year
    last_complete = PerformanceCalculator.year_complete?(current_year, as_of: @as_of) ? current_year : current_year - 1

    end_year = if include_ytd && !PerformanceCalculator.year_complete?(current_year, as_of: @as_of)
                 current_year
               else
                 last_complete
               end

    start_year = last_complete - lookback_years + 1
    start_year = [start_year, 2000].max
    (start_year..end_year).to_a
  end

  def build_point(asset_key, year, include_ytd)
    complete = PerformanceCalculator.year_complete?(year, as_of: @as_of)

    if complete
      start_price = @repository.prior_year_end_close(asset_key, year)
      end_price = @repository.year_end_close(asset_key, year)
      return_pct = PerformanceCalculator.relative_return_pct(start_price, end_price)
      return nil if return_pct.nil?

      PerformanceCalculator::Result.new(
        year: year,
        month: nil,
        return_pct: return_pct,
        start_price: start_price,
        end_price: end_price,
        label: year.to_s,
        complete: true,
        partial: false
      )
    elsif include_ytd && year == @as_of.year
      # YTD: from prior Dec close to latest completed month-end on or before as_of
      start_price = @repository.prior_year_end_close(asset_key, year)
      # Use last fully completed month
      end_month = latest_completed_month_in_year(year)
      return nil if end_month.nil?

      end_price = @repository.month_end_close(asset_key, year, end_month)
      return_pct = PerformanceCalculator.relative_return_pct(start_price, end_price)
      return nil if return_pct.nil?

      PerformanceCalculator::Result.new(
        year: year,
        month: end_month,
        return_pct: return_pct,
        start_price: start_price,
        end_price: end_price,
        label: "#{year} YTD",
        complete: false,
        partial: true
      )
    end
  end

  def latest_completed_month_in_year(year)
    if year < @as_of.year
      12
    elsif year > @as_of.year
      nil
    else
      # months strictly before current month are complete; if day is after month end of prior, etc.
      # Use calendar: any month M where month_complete?(year, M)
      (1..12).reverse_each.find { |m| PerformanceCalculator.month_complete?(year, m, as_of: @as_of) }
    end
  end

  def build_summary(points)
    return empty_summary if points.empty?

    returns = points.map(&:return_pct)
    positive = returns.count(&:positive?)
    avg = returns.sum / returns.size
    best = points.max_by(&:return_pct)
    worst = points.min_by(&:return_pct)

    {
      count: points.size,
      average_pct: avg,
      median_pct: median(returns),
      positive_years: positive,
      negative_years: returns.count(&:negative?),
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
      colors: points.map { |p| p.return_pct >= 0 ? "positive" : "negative" },
      partial: points.map(&:partial)
    }
  end
end
