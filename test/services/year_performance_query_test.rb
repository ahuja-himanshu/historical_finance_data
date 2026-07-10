# frozen_string_literal: true

require "test_helper"

class YearPerformanceQueryTest < ActiveSupport::TestCase
  AS_OF = Date.new(2026, 7, 9)

  setup do
    @repo = PriceRepository.new
    @query = YearPerformanceQuery.new(repository: @repo, as_of: AS_OF)
  end

  test "year-wise series for BTC includes multi-year signed percentages" do
    result = @query.call(asset_key: "btc", lookback_years: 10)

    assert_equal "year", result[:mode]
    complete = result[:points].reject(&:partial)
    assert complete.size >= 8, "expected multiple complete years"

    complete.each do |point|
      expected = PerformanceCalculator.relative_return_pct(point.start_price, point.end_price)
      assert_in_delta expected, point.return_pct, 0.0001
      assert_equal point.year.to_s, point.label
      assert point.complete
    end
  end

  test "current incomplete year is labeled YTD and marked partial" do
    result = @query.call(asset_key: "gold", lookback_years: 10, include_ytd: true)
    ytd = result[:points].find(&:partial)

    assert ytd, "expected a YTD point for 2026"
    assert_equal 2026, ytd.year
    assert_equal "2026 YTD", ytd.label
    assert_not ytd.complete
    assert ytd.partial

    # YTD uses prior Dec close → latest completed month in 2026 (June)
    assert_equal @repo.prior_year_end_close("gold", 2026), ytd.start_price
    assert_equal @repo.month_end_close("gold", 2026, 6), ytd.end_price
    expected = PerformanceCalculator.relative_return_pct(ytd.start_price, ytd.end_price)
    assert_in_delta expected, ytd.return_pct, 0.0001
  end

  test "include_ytd false omits incomplete current year" do
    result = @query.call(asset_key: "spx", lookback_years: 10, include_ytd: false)
    years = result[:points].map(&:year)
    assert_not_includes years, 2026
    assert result[:points].none?(&:partial)
  end

  test "equity index Dow Jones year path" do
    result = @query.call(asset_key: "dji", lookback_years: 10)
    assert result[:points].any?
    result[:points].reject(&:partial).each do |p|
      start_px = @repo.prior_year_end_close("dji", p.year)
      end_px = @repo.year_end_close("dji", p.year)
      expected = PerformanceCalculator.relative_return_pct(start_px, end_px)
      assert_in_delta expected, p.return_pct, 0.0001
    end
  end

  test "commodity silver year path" do
    result = @query.call(asset_key: "silver", lookback_years: 8)
    assert result[:chart][:labels].size == result[:points].size
    assert result[:summary][:count] == result[:points].reject(&:partial).size
  end

  test "summary ignores partial YTD for average stats" do
    result = @query.call(asset_key: "eth", lookback_years: 10)
    complete_returns = result[:points].reject(&:partial).map(&:return_pct)
    avg = complete_returns.sum / complete_returns.size
    assert_in_delta avg, result[:summary][:average_pct], 0.0001
  end
end
