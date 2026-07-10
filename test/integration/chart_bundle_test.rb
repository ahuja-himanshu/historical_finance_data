# frozen_string_literal: true

require "test_helper"

# Guards criterion-4: Chart.js must load as a self-contained bundle so the
# performance chart Stimulus controller can construct bar charts in the browser.
class ChartBundleTest < ActionDispatch::IntegrationTest
  test "public chart UMD is self-contained without broken jspm chunk imports" do
    path = Rails.root.join("public/chart.umd.min.js")
    assert path.exist?, "expected public/chart.umd.min.js to exist"

    body = path.read
    assert_includes body, "Chart.js", "expected Chart.js banner in UMD file"
    assert_includes body, "window.Chart", "UMD must assign window.Chart"

    # The broken jspm ESM pin imported ../_/MwoWUuIu.js — that must not reappear
    refute_match(%r{\.\./_/MwoWUuIu}, body)
    refute_match(%r{from\s*["']\.\./}, body)
  end

  test "layout loads UMD script before importmap and controller uses window.Chart" do
    get root_path
    assert_response :success

    assert_includes response.body, 'src="/chart.umd.min.js"'
    # chart script appears before importmap entry
    umd_pos = response.body.index('src="/chart.umd.min.js"')
    importmap_pos = response.body.index("importmap") || response.body.index("application.js")
    assert umd_pos, "UMD script tag missing from layout"
    assert importmap_pos, "importmap tags missing"
    assert umd_pos < importmap_pos, "Chart UMD must load before importmap modules"

    assert_select "[data-controller='performance-chart']"
    assert_select "canvas[data-performance-chart-target='canvas']"
  end

  test "chart UMD is served over HTTP without missing module chunks" do
    get "/chart.umd.min.js"
    assert_response :success
    assert_operator response.body.bytesize, :>, 50_000
    assert_includes response.body, "window.Chart"
    refute_match(%r{\.\./_/MwoWUuIu}, response.body)
  end

  test "performance_chart_controller does not import multi-chunk chart.js ESM" do
    source = Rails.root.join("app/javascript/controllers/performance_chart_controller.js").read
    refute_match(/from\s+["']chart\.js["']/, source)
    assert_match(/window\.Chart/, source)
    assert_match(/new Chart\(/, source)
  end

  test "importmap no longer pins broken chart.js ESM entry" do
    importmap = Rails.root.join("config/importmap.rb").read
    refute_match(/pin\s+["']chart\.js["']/, importmap)
    refute_match(/@kurkle\/color/, importmap)
  end

  test "month view chart payload binds labels and values for plotting" do
    get root_path, params: { asset: "btc", mode: "month", month: 8, lookback: 10, as_of: "2026-07-09" }
    assert_response :success

    assert_select "[data-performance-chart-payload-value]" do |elements|
      payload = CGI.unescapeHTML(elements.first["data-performance-chart-payload-value"])
      parsed = JSON.parse(payload)
      assert parsed["labels"].size >= 5
      assert_equal parsed["labels"].size, parsed["values"].size
      assert parsed["values"].all? { |v| v.is_a?(Numeric) }
      assert_equal "month", parsed["mode"]
    end
  end
end
