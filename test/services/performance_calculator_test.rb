# frozen_string_literal: true

require "test_helper"

class PerformanceCalculatorTest < ActiveSupport::TestCase
  test "relative_return_pct computes signed percentage from start and end" do
    assert_in_delta 10.0, PerformanceCalculator.relative_return_pct(100, 110), 0.0001
    assert_in_delta(-25.0, PerformanceCalculator.relative_return_pct(200, 150), 0.0001)
    assert_in_delta 0.0, PerformanceCalculator.relative_return_pct(50, 50), 0.0001
  end

  test "relative_return_pct returns nil for invalid inputs" do
    assert_nil PerformanceCalculator.relative_return_pct(nil, 100)
    assert_nil PerformanceCalculator.relative_return_pct(100, nil)
    assert_nil PerformanceCalculator.relative_return_pct(0, 100)
  end

  test "month_complete? is true only after the month ends" do
    as_of = Date.new(2026, 8, 15)
    assert PerformanceCalculator.month_complete?(2026, 7, as_of: as_of)
    assert_not PerformanceCalculator.month_complete?(2026, 8, as_of: as_of)
    assert PerformanceCalculator.month_complete?(2025, 8, as_of: as_of)
  end

  test "month_complete? on last day of month is still incomplete" do
    as_of = Date.new(2026, 8, 31)
    assert_not PerformanceCalculator.month_complete?(2026, 8, as_of: as_of)
    assert PerformanceCalculator.month_complete?(2026, 8, as_of: Date.new(2026, 9, 1))
  end

  test "year_complete? requires date after Dec 31" do
    assert_not PerformanceCalculator.year_complete?(2025, as_of: Date.new(2025, 12, 31))
    assert PerformanceCalculator.year_complete?(2025, as_of: Date.new(2026, 1, 1))
  end

  test "include_current_year_for_month? when month already passed" do
    as_of = Date.new(2026, 9, 10)
    assert PerformanceCalculator.include_current_year_for_month?(8, as_of: as_of)
    assert_not PerformanceCalculator.include_current_year_for_month?(9, as_of: as_of)
    assert_not PerformanceCalculator.include_current_year_for_month?(12, as_of: as_of)
  end

  test "format_signed_pct includes plus for gains" do
    assert_equal "+12.50%", PerformanceCalculator.format_signed_pct(12.5)
    assert_equal "-3.25%", PerformanceCalculator.format_signed_pct(-3.25)
    assert_equal "—", PerformanceCalculator.format_signed_pct(nil)
  end
end
