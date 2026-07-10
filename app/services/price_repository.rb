# frozen_string_literal: true

require "yaml"

# Loads month-end close series from seeded YAML under lib/data/prices.
# Series keys are "YYYY-MM" strings; values are floats.
class PriceRepository
  DATA_DIR = Rails.root.join("lib/data/prices")

  def initialize(data_dir: DATA_DIR)
    @data_dir = Pathname(data_dir)
    @cache = {}
  end

  def series_for(asset_key)
    key = asset_key.to_s
    @cache[key] ||= load_series(key)
  end

  # Returns month-end close for year/month, or nil if missing.
  def month_end_close(asset_key, year, month)
    series_for(asset_key)[format("%04d-%02d", year, month)]
  end

  # Previous calendar month-end close relative to year/month.
  def previous_month_end_close(asset_key, year, month)
    date = Date.new(year, month, 1) << 1
    month_end_close(asset_key, date.year, date.month)
  end

  # December close of the prior calendar year.
  def prior_year_end_close(asset_key, year)
    month_end_close(asset_key, year - 1, 12)
  end

  def year_end_close(asset_key, year)
    month_end_close(asset_key, year, 12)
  end

  # Latest available close on or before as_of (month-end of that month if present).
  def latest_close_on_or_before(asset_key, as_of)
    series = series_for(asset_key)
    cutoff = format("%04d-%02d", as_of.year, as_of.month)
    eligible = series.keys.select { |k| k <= cutoff }.max
    eligible ? series[eligible] : nil
  end

  def available_years(asset_key)
    series_for(asset_key).keys.map { |k| k[0, 4].to_i }.uniq.sort
  end

  def metadata(asset_key)
    path = file_path(asset_key)
    return {} unless path.exist?

    raw = YAML.safe_load_file(path, permitted_classes: [Date, Time, Symbol], aliases: true) || {}
    raw.except("series")
  end

  private

  def load_series(asset_key)
    path = file_path(asset_key)
    raise ArgumentError, "No price data for asset #{asset_key.inspect}" unless path.exist?

    raw = YAML.safe_load_file(path, permitted_classes: [Date, Time, Symbol], aliases: true)
    series = raw.fetch("series")
    series.transform_values { |v| v.to_f }.sort.to_h
  end

  def file_path(asset_key)
    @data_dir.join("#{asset_key}.yml")
  end
end
