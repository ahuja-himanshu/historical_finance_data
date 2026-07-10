# frozen_string_literal: true

require "test_helper"

class PriceRepositoryTest < ActiveSupport::TestCase
  setup do
    @repo = PriceRepository.new
  end

  test "loads series for all eight supported assets" do
    Asset.keys.each do |key|
      series = @repo.series_for(key)
      assert series.any?, "expected prices for #{key}"
      assert series.values.all? { |v| v.is_a?(Float) || v.is_a?(Numeric) }
    end
  end

  test "month_end_close and previous_month_end_close are consistent" do
    close = @repo.month_end_close("btc", 2020, 3)
    prev = @repo.previous_month_end_close("btc", 2020, 3)
    assert close.is_a?(Numeric)
    assert prev.is_a?(Numeric)
    assert_equal @repo.month_end_close("btc", 2020, 2), prev
  end

  test "missing asset raises" do
    assert_raises(ArgumentError) { @repo.series_for("nope") }
  end
end
