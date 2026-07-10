/* global Chart, SeasonalPerformance */
(function () {
  "use strict";

  var SP = SeasonalPerformance;
  var state = {
    catalog: [],
    repo: null,
    chart: null
  };

  function $(sel) {
    return document.querySelector(sel);
  }

  function pctClass(v) {
    if (v == null || !isFinite(v)) return "pct-flat";
    if (v > 0) return "pct-positive";
    if (v < 0) return "pct-negative";
    return "pct-flat";
  }

  function formatPrice(value, asset) {
    if (value == null) return "—";
    var n = Number(value);
    if (asset.category === "crypto" || asset.key === "gold" || asset.key === "silver") {
      if (n >= 100) return "$" + Math.round(n).toLocaleString("en-US");
      return "$" + n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    return n.toLocaleString("en-US", { maximumFractionDigits: 2 });
  }

  function badgeClass(category) {
    if (category === "crypto") return "badge-crypto";
    if (category === "equity_index") return "badge-equity";
    if (category === "commodity") return "badge-commodity";
    return "badge-default";
  }

  function withAlpha(color, alpha) {
    if (color.charAt(0) === "#" && color.length === 7) {
      var r = parseInt(color.slice(1, 3), 16);
      var g = parseInt(color.slice(3, 5), 16);
      var b = parseInt(color.slice(5, 7), 16);
      return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
    }
    return color;
  }

  function renderChart(result) {
    var canvas = $("#perf-chart");
    if (!canvas || typeof Chart === "undefined") return;
    var styles = getComputedStyle(document.documentElement);
    var pos = styles.getPropertyValue("--color-positive").trim() || "#12b886";
    var neg = styles.getPropertyValue("--color-negative").trim() || "#fa5252";
    var grid = styles.getPropertyValue("--color-grid").trim() || "rgba(148,163,184,0.12)";
    var text = styles.getPropertyValue("--color-muted").trim() || "#94a3b8";
    var chart = result.chart;
    var bg = chart.values.map(function (v, i) {
      var base = v >= 0 ? pos : neg;
      if (chart.partial && chart.partial[i]) return withAlpha(base, 0.45);
      return base;
    });

    if (state.chart) state.chart.destroy();
    state.chart = new Chart(canvas.getContext("2d"), {
      type: "bar",
      data: {
        labels: chart.labels,
        datasets: [{
          label: "Return %",
          data: chart.values,
          backgroundColor: bg,
          borderRadius: 6,
          borderSkipped: false,
          maxBarThickness: 42
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 650, easing: "easeOutQuart" },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.92)",
            titleFont: { family: "'IBM Plex Sans', sans-serif", size: 13 },
            bodyFont: { family: "'IBM Plex Mono', monospace", size: 12 },
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: function (ctx) {
                var val = ctx.parsed.y;
                var sign = val > 0 ? "+" : "";
                var partial = chart.partial && chart.partial[ctx.dataIndex] ? " (YTD)" : "";
                return " " + sign + val.toFixed(2) + "%" + partial;
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: text, font: { family: "'IBM Plex Sans', sans-serif", size: 11 } },
            border: { display: false }
          },
          y: {
            grid: { color: grid, drawBorder: false },
            ticks: {
              color: text,
              font: { family: "'IBM Plex Mono', monospace", size: 11 },
              callback: function (v) { return v + "%"; }
            },
            border: { display: false }
          }
        }
      }
    });
  }

  function renderResult(result) {
    var mode = result.mode;
    var asset = result.asset;
    var summary = result.summary;
    var points = result.points;

    $("#page-heading").innerHTML =
      'How has <span class="accent">' + asset.name + "</span> performed?";
    $("#meta-asof").textContent = result.as_of;
    $("#meta-lookback").textContent = result.lookback_years + " years";
    $("#meta-mode").textContent = mode === "year" ? "Year-wise" : "Month-wise";

    var title =
      mode === "year"
        ? asset.name + " — Calendar year returns"
        : asset.name + " — " + result.month_name + " returns by year";
    $("#chart-title").textContent = title;
    $("#chart-sub").textContent =
      mode === "year"
        ? "Each bar is calendar-year return vs prior December close. YTD is partial."
        : "Each bar is " + result.month_name + " return vs prior month-end close.";

    $("#stat-count").textContent = summary.count;
    $("#stat-avg").textContent = SP.formatSignedPct(summary.average_pct);
    $("#stat-avg").className = "mono " + pctClass(summary.average_pct);
    $("#stat-median").textContent = SP.formatSignedPct(summary.median_pct);
    $("#stat-median").className = "mono " + pctClass(summary.median_pct);
    $("#stat-pos").textContent = summary.positive_years;
    $("#stat-neg").textContent = summary.negative_years;
    $("#stat-hit").textContent =
      summary.win_rate_pct == null ? "—" : summary.win_rate_pct.toFixed(1) + "%";
    $("#stat-best").textContent = summary.best
      ? summary.best.year + " · " + SP.formatSignedPct(summary.best.return_pct)
      : "—";
    $("#stat-worst").textContent = summary.worst
      ? summary.worst.year + " · " + SP.formatSignedPct(summary.worst.return_pct)
      : "—";

    var tbody = $("#series-body");
    tbody.innerHTML = "";
    if (!points.length) {
      $("#empty-chart").hidden = false;
      $("#chart-wrap").hidden = true;
      tbody.innerHTML =
        '<tr><td colspan="5" class="muted">No completed periods for this selection.</td></tr>';
    } else {
      $("#empty-chart").hidden = true;
      $("#chart-wrap").hidden = false;
      var rows = points.slice().reverse();
      rows.forEach(function (p) {
        var tr = document.createElement("tr");
        if (p.partial) tr.className = "row-partial";
        tr.innerHTML =
          '<td class="mono">' + p.label + "</td>" +
          '<td class="mono ' + pctClass(p.return_pct) + '">' + SP.formatSignedPct(p.return_pct) + "</td>" +
          '<td class="mono muted">' + formatPrice(p.start_price, asset) + "</td>" +
          '<td class="mono muted">' + formatPrice(p.end_price, asset) + "</td>" +
          "<td>" +
          (p.partial
            ? '<span class="status-pill status-ytd">YTD</span>'
            : '<span class="status-pill status-complete">Complete</span>') +
          "</td>";
        tbody.appendChild(tr);
      });
      renderChart(result);
    }

    // Store chart payload for tests/scrapers
    var bind = $("#chart-bind");
    if (bind) {
      bind.setAttribute(
        "data-performance-chart-payload",
        JSON.stringify({
          labels: result.chart.labels,
          values: result.chart.values,
          colors: result.chart.colors,
          partial: result.chart.partial,
          mode: result.mode,
          title: title
        })
      );
    }
  }

  function currentParams() {
    return {
      asset: $("#asset-select").value,
      mode: $("#mode-select").value,
      month: Number($("#month-select").value),
      lookback: Number($("#lookback-select").value)
    };
  }

  function run() {
    var p = currentParams();
    $("#month-field").style.display = p.mode === "month" ? "" : "none";
    document.querySelectorAll(".asset-chip").forEach(function (el) {
      el.classList.toggle("asset-chip-active", el.getAttribute("data-key") === p.asset);
    });

    var asOf = new Date();
    var asOfStr =
      asOf.getFullYear() +
      "-" +
      String(asOf.getMonth() + 1).padStart(2, "0") +
      "-" +
      String(asOf.getDate()).padStart(2, "0");

    var result;
    if (p.mode === "year") {
      result = SP.yearPerformance(state.repo, state.catalog, {
        asset_key: p.asset,
        lookback_years: p.lookback,
        as_of: asOfStr,
        include_ytd: true
      });
    } else {
      result = SP.monthPerformance(state.repo, state.catalog, {
        asset_key: p.asset,
        month: p.month,
        lookback_years: p.lookback,
        as_of: asOfStr
      });
    }
    renderResult(result);
  }

  function populateControls() {
    var assetSelect = $("#asset-select");
    var monthSelect = $("#month-select");
    var strip = $("#asset-strip");
    assetSelect.innerHTML = "";
    strip.innerHTML = "";
    state.catalog.forEach(function (a, idx) {
      var opt = document.createElement("option");
      opt.value = a.key;
      opt.textContent = a.name + " (" + a.symbol + ")";
      if (idx === 0) opt.selected = true;
      assetSelect.appendChild(opt);

      var chip = document.createElement("button");
      chip.type = "button";
      chip.className = "asset-chip" + (idx === 0 ? " asset-chip-active" : "");
      chip.setAttribute("data-key", a.key);
      chip.setAttribute("role", "listitem");
      chip.innerHTML =
        '<span class="asset-chip-name">' +
        a.symbol +
        '</span><span class="' +
        badgeClass(a.category) +
        '">' +
        a.category.replace("_", " ") +
        "</span>";
      chip.addEventListener("click", function () {
        assetSelect.value = a.key;
        run();
      });
      strip.appendChild(chip);
    });

    monthSelect.innerHTML = "";
    for (var m = 1; m <= 12; m++) {
      var o = document.createElement("option");
      o.value = String(m);
      o.textContent = SP.MONTH_NAMES[m];
      if (m === new Date().getMonth() + 1) o.selected = true;
      monthSelect.appendChild(o);
    }
  }

  function bindForm() {
    ["asset-select", "mode-select", "month-select", "lookback-select"].forEach(function (id) {
      $( "#" + id ).addEventListener("change", run);
    });
    $("#query-form").addEventListener("submit", function (e) {
      e.preventDefault();
      run();
    });
  }

  function boot(payload) {
    state.catalog = payload.assets;
    state.repo = new SP.PriceRepository(payload.prices);
    populateControls();
    bindForm();
    run();
  }

  // Relative path so project Pages (/repo/) and local file/server both work.
  fetch("./data/prices.json")
    .then(function (r) {
      if (!r.ok) throw new Error("Failed to load prices.json: " + r.status);
      return r.json();
    })
    .then(boot)
    .catch(function (err) {
      console.error(err);
      var el = $("#boot-error");
      if (el) {
        el.hidden = false;
        el.textContent = "Could not load market data: " + err.message;
      }
    });
})();
