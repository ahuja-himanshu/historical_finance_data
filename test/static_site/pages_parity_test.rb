# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"

# Verifies the GitHub Pages static site shares data + calc with the Rails app.
class PagesParityTest < ActiveSupport::TestCase
  AS_OF = "2026-07-09"
  DOCS = Rails.root.join("docs")
  PERF_JS = DOCS.join("js/performance.js")
  PRICES_JSON = DOCS.join("data/prices.json")

  test "static site artifacts exist for Pages hosting" do
    %w[
      index.html
      .nojekyll
      chart.umd.min.js
      css/desk.css
      js/performance.js
      js/app.js
      data/prices.json
    ].each do |rel|
      path = DOCS.join(rel)
      assert path.exist?, "missing Pages artifact: docs/#{rel}"
    end
  end

  test "pages index includes all eight assets and controls" do
    html = DOCS.join("index.html").read
    assert_match(/asset-select/, html)
    assert_match(/mode-select/, html)
    assert_match(/month-select/, html)
    assert_match(/Seasonal Desk/, html)
    assert_match(/chart.umd.min.js/, html)
    assert_match(/performance.js/, html)

    payload = JSON.parse(PRICES_JSON.read)
    keys = payload["assets"].map { |a| a["key"] }
    assert_equal Asset.keys, keys

    Asset.all.each do |asset|
      assert payload["prices"].key?(asset.key), "prices.json missing #{asset.key}"
      assert payload["prices"][asset.key]["series"].any?
    end
  end

  test "exported prices.json matches PriceRepository series for every asset" do
    payload = JSON.parse(PRICES_JSON.read)
    repo = PriceRepository.new
    Asset.keys.each do |key|
      expected = repo.series_for(key)
      actual = payload["prices"][key]["series"]
      assert_equal expected.keys, actual.keys.sort, "series keys mismatch for #{key}"
      expected.each do |ym, price|
        assert_in_delta price, actual[ym].to_f, 0.0001, "#{key} #{ym}"
      end
    end
  end

  test "static JS month-wise BTC August matches Rails MonthPerformanceQuery" do
    ruby = MonthPerformanceQuery.new(as_of: Date.parse(AS_OF)).call(
      asset_key: "btc", month: 8, lookback_years: 10
    )
    js = run_js_month(asset: "btc", month: 8, lookback: 10, as_of: AS_OF)

    assert js["points"].any?, "JS returned no points"
    assert_equal ruby[:points].map(&:year), js["points"].map { |p| p["year"] }
    ruby[:points].zip(js["points"]).each do |r, j|
      assert_in_delta r.return_pct, j["return_pct"], 0.0001
      assert_in_delta r.start_price, j["start_price"], 0.0001
      assert_in_delta r.end_price, j["end_price"], 0.0001
      assert_equal r.label, j["label"]
    end
    # current year excluded for incomplete August as of July 2026
    assert_not_includes js["points"].map { |p| p["year"] }, 2026
  end

  test "static JS includes current year for completed month matching Rails" do
    ruby = MonthPerformanceQuery.new(as_of: Date.parse(AS_OF)).call(
      asset_key: "spx", month: 6, lookback_years: 5
    )
    js = run_js_month(asset: "spx", month: 6, lookback: 5, as_of: AS_OF)
    assert_includes ruby[:points].map(&:year), 2026
    assert_includes js["points"].map { |p| p["year"] }, 2026
    ruby[:points].zip(js["points"]).each do |r, j|
      assert_in_delta r.return_pct, j["return_pct"], 0.0001
    end
  end

  test "static JS year-wise gold matches Rails including YTD" do
    ruby = YearPerformanceQuery.new(as_of: Date.parse(AS_OF)).call(
      asset_key: "gold", lookback_years: 10, include_ytd: true
    )
    js = run_js_year(asset: "gold", lookback: 10, as_of: AS_OF)

    assert_equal ruby[:points].map(&:label), js["points"].map { |p| p["label"] }
    ruby[:points].zip(js["points"]).each do |r, j|
      assert_in_delta r.return_pct, j["return_pct"], 0.0001
      assert_equal r.partial, j["partial"]
    end
    ytd = js["points"].find { |p| p["partial"] }
    assert ytd, "expected YTD point"
    assert_equal "2026 YTD", ytd["label"]
  end

  test "static JS relative_return_pct and period rules match Ruby calculator" do
    script = <<~JS
      const SP = require(#{PERF_JS.to_s.to_json});
      const out = {
        gain: SP.relativeReturnPct(100, 110),
        loss: SP.relativeReturnPct(200, 150),
        augComplete: SP.monthComplete(2026, 8, "2026-09-01"),
        augIncomplete: SP.monthComplete(2026, 8, "2026-08-31"),
        includeAug: SP.includeCurrentYearForMonth(8, "2026-09-05"),
        excludeJul: SP.includeCurrentYearForMonth(7, "2026-07-09")
      };
      process.stdout.write(JSON.stringify(out));
    JS
    js = JSON.parse(run_node(script))
    assert_in_delta PerformanceCalculator.relative_return_pct(100, 110), js["gain"], 0.0001
    assert_in_delta PerformanceCalculator.relative_return_pct(200, 150), js["loss"], 0.0001
    assert_equal true, js["augComplete"]
    assert_equal false, js["augIncomplete"]
    assert_equal true, js["includeAug"]
    assert_equal false, js["excludeJul"]
  end

  private

  def run_js_month(asset:, month:, lookback:, as_of:)
    script = <<~JS
      const fs = require("fs");
      const SP = require(#{PERF_JS.to_s.to_json});
      const data = JSON.parse(fs.readFileSync(#{PRICES_JSON.to_s.to_json}, "utf8"));
      const repo = new SP.PriceRepository(data.prices);
      const result = SP.monthPerformance(repo, data.assets, {
        asset_key: #{asset.to_json},
        month: #{month},
        lookback_years: #{lookback},
        as_of: #{as_of.to_json}
      });
      process.stdout.write(JSON.stringify(result));
    JS
    JSON.parse(run_node(script))
  end

  def run_js_year(asset:, lookback:, as_of:)
    script = <<~JS
      const fs = require("fs");
      const SP = require(#{PERF_JS.to_s.to_json});
      const data = JSON.parse(fs.readFileSync(#{PRICES_JSON.to_s.to_json}, "utf8"));
      const repo = new SP.PriceRepository(data.prices);
      const result = SP.yearPerformance(repo, data.assets, {
        asset_key: #{asset.to_json},
        lookback_years: #{lookback},
        as_of: #{as_of.to_json},
        include_ytd: true
      });
      process.stdout.write(JSON.stringify(result));
    JS
    JSON.parse(run_node(script))
  end

  def run_node(script)
    stdout, stderr, status = Open3.capture3("node", "-e", script)
    assert status.success?, "node failed: #{stderr}\n#{stdout}"
    stdout
  end
end
