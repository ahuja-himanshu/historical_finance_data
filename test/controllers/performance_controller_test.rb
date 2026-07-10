# frozen_string_literal: true

require "test_helper"

class PerformanceControllerTest < ActionDispatch::IntegrationTest
  test "root page succeeds and shows asset selection controls" do
    get root_path
    assert_response :success

    assert_select "select[name=asset]"
    assert_select "select[name=mode]"
    assert_select "select[name=month]"
    assert_select "select[name=lookback]"

    Asset.all.each do |asset|
      assert_match asset.symbol, response.body
    end
  end

  test "month-wise BTC August shows year labels and signed percentages" do
    get root_path, params: { asset: "btc", mode: "month", month: 8, lookback: 10, as_of: "2026-07-09" }
    assert_response :success

    assert_match(/August/i, response.body)
    assert_match(/Bitcoin/i, response.body)

    # Table structure and chart binding present
    assert_select "table.data-table"
    assert_select "[data-controller='performance-chart']"
    assert_select "[data-performance-chart-payload-value]"

    # Signed percentage pattern appears
    assert_match(/[+\-]\d+\.\d{2}%/, response.body)

    # Year labels in series (multi-year)
    body = response.body
    years_found = body.scan(/\b(20\d{2})\b/).flatten.uniq
    assert years_found.size >= 5, "expected multiple year labels, got #{years_found.inspect}"
  end

  test "month-wise includes current year when month already complete" do
    get root_path, params: { asset: "spx", mode: "month", month: 6, lookback: 10, as_of: "2026-07-09" }
    assert_response :success
    assert_match(/2026/, response.body)
  end

  test "year-wise view shows multi-year series and chart config" do
    get root_path, params: { asset: "gold", mode: "year", lookback: 10, as_of: "2026-07-09" }
    assert_response :success

    assert_match(/Gold/i, response.body)
    assert_match(/Year-wise|Calendar year/i, response.body)
    assert_select "[data-controller='performance-chart']"
    assert_select "table.data-table tbody tr", minimum: 5

    # YTD label for incomplete current year
    assert_match(/YTD/, response.body)
    assert_match(/[+\-]\d+\.\d{2}%/, response.body)

    # Chart payload embeds values JSON
    assert_select "[data-performance-chart-payload-value]" do |elements|
      payload = CGI.unescapeHTML(elements.first["data-performance-chart-payload-value"])
      parsed = JSON.parse(payload)
      assert parsed["labels"].is_a?(Array)
      assert parsed["values"].is_a?(Array)
      assert parsed["labels"].size == parsed["values"].size
      assert parsed["labels"].size >= 5
    end
  end

  test "invalid asset falls back to btc" do
    get root_path, params: { asset: "zzz", mode: "month", month: 1 }
    assert_response :success
    assert_match(/Bitcoin/i, response.body)
  end

  test "all eight assets are selectable" do
    get root_path
    assert_response :success
    Asset.keys.each do |key|
      assert_select "option[value=?]", key
    end
  end

  test "nifty and banknifty pages load" do
    get root_path, params: { asset: "nifty", mode: "year", lookback: 10, as_of: "2026-07-09" }
    assert_response :success
    assert_match(/Nifty/i, response.body)

    get root_path, params: { asset: "banknifty", mode: "month", month: 1, lookback: 10, as_of: "2026-07-09" }
    assert_response :success
    assert_match(/Bank Nifty/i, response.body)
  end
end
