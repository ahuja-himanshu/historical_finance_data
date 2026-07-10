# frozen_string_literal: true

require "test_helper"

class MonthPerformanceQueryTest < ActiveSupport::TestCase
  # Fixed as-of: 2026-07-09 (matches environment "today" for this goal)
  AS_OF = Date.new(2026, 7, 9)

  setup do
    @repo = PriceRepository.new
    @query = MonthPerformanceQuery.new(repository: @repo, as_of: AS_OF)
  end

  test "BTC August multi-year series returns signed percentages from real price path" do
    result = @query.call(asset_key: "btc", month: 8, lookback_years: 10)

    assert_equal "month", result[:mode]
    assert_equal "btc", result[:asset].key
    assert_equal 8, result[:month]
    assert_equal "August", result[:month_name]
    assert result[:points].any?, "expected August history for BTC"

    result[:points].each do |point|
      assert point.year.is_a?(Integer)
      assert point.return_pct.is_a?(Numeric)
      assert point.complete
      assert_not point.partial

      # Prove calc path: recompute from prices returned by the shipped result
      expected = PerformanceCalculator.relative_return_pct(point.start_price, point.end_price)
      assert_in_delta expected, point.return_pct, 0.0001

      # Also recompute from repository (true shipped data source)
      start_px = @repo.previous_month_end_close("btc", point.year, 8)
      end_px = @repo.month_end_close("btc", point.year, 8)
      assert_in_delta start_px, point.start_price, 0.0001
      assert_in_delta end_px, point.end_price, 0.0001
    end

    # Chart bindings match table series
    assert_equal result[:points].map(&:label), result[:chart][:labels]
    assert_equal result[:points].size, result[:chart][:values].size
  end

  test "current year included for completed month and excluded for incomplete month" do
    # June 2026 is complete as of July 9 2026 → current year should appear
    june = @query.call(asset_key: "spx", month: 6, lookback_years: 10)
    years_june = june[:points].map(&:year)
    assert_includes years_june, 2026, "June 2026 should be included after month end"

    # July 2026 is incomplete as of July 9 → must omit 2026
    july = @query.call(asset_key: "spx", month: 7, lookback_years: 10)
    years_july = july[:points].map(&:year)
    assert_not_includes years_july, 2026, "July 2026 incomplete must be excluded"

    # August has not started/completed → exclude 2026
    august = @query.call(asset_key: "btc", month: 8, lookback_years: 10)
    assert_not_includes august[:points].map(&:year), 2026
  end

  test "equity index month path works for S&P 500" do
    result = @query.call(asset_key: "spx", month: 3, lookback_years: 8)
    assert result[:points].size >= 5
    result[:points].each do |p|
      expected = PerformanceCalculator.relative_return_pct(p.start_price, p.end_price)
      assert_in_delta expected, p.return_pct, 0.0001
    end
    assert result[:summary][:count] == result[:points].size
    assert result[:summary][:average_pct].is_a?(Numeric)
  end

  test "commodity month path works for gold" do
    result = @query.call(asset_key: "gold", month: 11, lookback_years: 10)
    assert result[:points].any?
    result[:points].each do |p|
      assert p.return_pct.is_a?(Numeric)
      expected = ((p.end_price / p.start_price) - 1.0) * 100.0
      assert_in_delta expected, p.return_pct, 0.0001
    end
  end

  test "unsupported asset raises" do
    assert_raises(ArgumentError) { @query.call(asset_key: "not_real", month: 1) }
  end

  test "invalid month raises" do
    assert_raises(ArgumentError) { @query.call(asset_key: "btc", month: 13) }
  end

  test "with fixed as_of in September includes current August" do
    q = MonthPerformanceQuery.new(repository: @repo, as_of: Date.new(2025, 9, 5))
    result = q.call(asset_key: "eth", month: 8, lookback_years: 5)
    years = result[:points].map(&:year)
    assert_includes years, 2025, "August 2025 must be included when as_of is September 2025"
  end
end
