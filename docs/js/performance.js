/**
 * Seasonal Desk — static performance engine.
 * Mirrors Rails PerformanceCalculator + Month/YearPerformanceQuery so the
 * GitHub Pages site uses the same relative-return math and period rules.
 *
 * Works in browsers (window.SeasonalPerformance) and Node (module.exports).
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.SeasonalPerformance = factory();
  }
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  var MONTH_NAMES = [
    null,
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  function pad2(n) {
    return n < 10 ? "0" + n : String(n);
  }

  function ymKey(year, month) {
    return year + "-" + pad2(month);
  }

  function parseISODate(s) {
    if (s instanceof Date) return new Date(s.getFullYear(), s.getMonth(), s.getDate());
    var parts = String(s).slice(0, 10).split("-");
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  function formatISODate(d) {
    d = parseISODate(d);
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
  }

  function daysInMonth(year, month) {
    return new Date(year, month, 0).getDate();
  }

  function relativeReturnPct(startPrice, endPrice) {
    if (startPrice == null || endPrice == null) return null;
    var s = Number(startPrice);
    var e = Number(endPrice);
    if (!isFinite(s) || !isFinite(e) || s === 0) return null;
    return ((e / s) - 1.0) * 100.0;
  }

  function monthComplete(year, month, asOf) {
    var d = parseISODate(asOf);
    var lastDay = new Date(year, month - 1, daysInMonth(year, month));
    return lastDay < d;
  }

  function yearComplete(year, asOf) {
    var d = parseISODate(asOf);
    var last = new Date(year, 11, 31);
    return last < d;
  }

  function includeCurrentYearForMonth(month, asOf) {
    var d = parseISODate(asOf);
    return monthComplete(d.getFullYear(), month, d);
  }

  function formatSignedPct(value, precision) {
    if (value == null || !isFinite(value)) return "—";
    precision = precision == null ? 2 : precision;
    var rounded = Number(value.toFixed(precision));
    var sign = rounded > 0 ? "+" : "";
    return sign + rounded.toFixed(precision) + "%";
  }

  function PriceRepository(pricesByAsset) {
    this.prices = pricesByAsset || {};
  }

  PriceRepository.prototype.seriesFor = function (assetKey) {
    var pack = this.prices[assetKey];
    if (!pack || !pack.series) throw new Error("No price data for asset " + assetKey);
    return pack.series;
  };

  PriceRepository.prototype.monthEndClose = function (assetKey, year, month) {
    var series = this.seriesFor(assetKey);
    var v = series[ymKey(year, month)];
    return v == null ? null : Number(v);
  };

  PriceRepository.prototype.previousMonthEndClose = function (assetKey, year, month) {
    var d = new Date(year, month - 1, 1);
    d.setMonth(d.getMonth() - 1);
    return this.monthEndClose(assetKey, d.getFullYear(), d.getMonth() + 1);
  };

  PriceRepository.prototype.priorYearEndClose = function (assetKey, year) {
    return this.monthEndClose(assetKey, year - 1, 12);
  };

  PriceRepository.prototype.yearEndClose = function (assetKey, year) {
    return this.monthEndClose(assetKey, year, 12);
  };

  function findAsset(catalog, key) {
    for (var i = 0; i < catalog.length; i++) {
      if (catalog[i].key === key) return catalog[i];
    }
    throw new Error("Unsupported asset: " + key);
  }

  function median(values) {
    if (!values.length) return null;
    var sorted = values.slice().sort(function (a, b) { return a - b; });
    var mid = Math.floor(sorted.length / 2);
    if (sorted.length % 2) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  function buildSummary(points) {
    if (!points.length) {
      return {
        count: 0,
        average_pct: null,
        median_pct: null,
        positive_years: 0,
        negative_years: 0,
        win_rate_pct: null,
        best: null,
        worst: null
      };
    }
    var returns = points.map(function (p) { return p.return_pct; });
    var positive = returns.filter(function (r) { return r > 0; }).length;
    var negative = returns.filter(function (r) { return r < 0; }).length;
    var sum = returns.reduce(function (a, b) { return a + b; }, 0);
    var best = points[0];
    var worst = points[0];
    for (var i = 1; i < points.length; i++) {
      if (points[i].return_pct > best.return_pct) best = points[i];
      if (points[i].return_pct < worst.return_pct) worst = points[i];
    }
    return {
      count: points.length,
      average_pct: sum / returns.length,
      median_pct: median(returns),
      positive_years: positive,
      negative_years: negative,
      win_rate_pct: (positive / points.length) * 100.0,
      best: { year: best.year, return_pct: best.return_pct },
      worst: { year: worst.year, return_pct: worst.return_pct }
    };
  }

  function chartPayload(points) {
    return {
      labels: points.map(function (p) { return p.label; }),
      values: points.map(function (p) { return Number(p.return_pct.toFixed(2)); }),
      colors: points.map(function (p) { return p.return_pct >= 0 ? "positive" : "negative"; }),
      partial: points.map(function (p) { return !!p.partial; })
    };
  }

  function monthPerformance(repo, catalog, opts) {
    var assetKey = opts.asset_key;
    var month = Number(opts.month);
    var lookback = Number(opts.lookback_years) || 10;
    if (lookback <= 0) lookback = 10;
    if (month < 1 || month > 12) throw new Error("month must be 1..12");
    var asOf = parseISODate(opts.as_of);
    var asset = findAsset(catalog, assetKey);

    var currentYear = asOf.getFullYear();
    var includeCurrent = includeCurrentYearForMonth(month, asOf);
    var endYear = includeCurrent ? currentYear : currentYear - 1;
    var startYear = Math.max(endYear - lookback + 1, 2000);
    var points = [];

    for (var year = startYear; year <= endYear; year++) {
      if (!monthComplete(year, month, asOf)) continue;
      var startPrice = repo.previousMonthEndClose(assetKey, year, month);
      var endPrice = repo.monthEndClose(assetKey, year, month);
      var ret = relativeReturnPct(startPrice, endPrice);
      if (ret == null) continue;
      points.push({
        year: year,
        month: month,
        return_pct: ret,
        start_price: startPrice,
        end_price: endPrice,
        label: String(year),
        complete: true,
        partial: false
      });
    }

    return {
      mode: "month",
      asset: asset,
      month: month,
      month_name: MONTH_NAMES[month],
      as_of: formatISODate(asOf),
      lookback_years: lookback,
      points: points,
      chart: chartPayload(points),
      summary: buildSummary(points)
    };
  }

  function latestCompletedMonthInYear(year, asOf) {
    var d = parseISODate(asOf);
    if (year < d.getFullYear()) return 12;
    if (year > d.getFullYear()) return null;
    for (var m = 12; m >= 1; m--) {
      if (monthComplete(year, m, d)) return m;
    }
    return null;
  }

  function yearPerformance(repo, catalog, opts) {
    var assetKey = opts.asset_key;
    var lookback = Number(opts.lookback_years) || 10;
    if (lookback <= 0) lookback = 10;
    var includeYtd = opts.include_ytd !== false;
    var asOf = parseISODate(opts.as_of);
    var asset = findAsset(catalog, assetKey);
    var currentYear = asOf.getFullYear();
    var lastComplete = yearComplete(currentYear, asOf) ? currentYear : currentYear - 1;
    var endYear = includeYtd && !yearComplete(currentYear, asOf) ? currentYear : lastComplete;
    var startYear = Math.max(lastComplete - lookback + 1, 2000);
    var points = [];

    for (var year = startYear; year <= endYear; year++) {
      var complete = yearComplete(year, asOf);
      if (complete) {
        var startPrice = repo.priorYearEndClose(assetKey, year);
        var endPrice = repo.yearEndClose(assetKey, year);
        var ret = relativeReturnPct(startPrice, endPrice);
        if (ret == null) continue;
        points.push({
          year: year,
          month: null,
          return_pct: ret,
          start_price: startPrice,
          end_price: endPrice,
          label: String(year),
          complete: true,
          partial: false
        });
      } else if (includeYtd && year === currentYear) {
        var ytdStart = repo.priorYearEndClose(assetKey, year);
        var endMonth = latestCompletedMonthInYear(year, asOf);
        if (endMonth == null) continue;
        var ytdEnd = repo.monthEndClose(assetKey, year, endMonth);
        var ytdRet = relativeReturnPct(ytdStart, ytdEnd);
        if (ytdRet == null) continue;
        points.push({
          year: year,
          month: endMonth,
          return_pct: ytdRet,
          start_price: ytdStart,
          end_price: ytdEnd,
          label: year + " YTD",
          complete: false,
          partial: true
        });
      }
    }

    var completePoints = points.filter(function (p) { return !p.partial; });
    return {
      mode: "year",
      asset: asset,
      as_of: formatISODate(asOf),
      lookback_years: lookback,
      include_ytd: includeYtd,
      points: points,
      chart: chartPayload(points),
      summary: buildSummary(completePoints)
    };
  }

  return {
    MONTH_NAMES: MONTH_NAMES,
    relativeReturnPct: relativeReturnPct,
    monthComplete: monthComplete,
    yearComplete: yearComplete,
    includeCurrentYearForMonth: includeCurrentYearForMonth,
    formatSignedPct: formatSignedPct,
    PriceRepository: PriceRepository,
    monthPerformance: monthPerformance,
    yearPerformance: yearPerformance
  };
});
