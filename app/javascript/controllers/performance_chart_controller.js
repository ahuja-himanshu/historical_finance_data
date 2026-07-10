import { Controller } from "@hotwired/stimulus"

// Chart.js is provided as a self-contained UMD global (window.Chart) from
// public/chart.umd.min.js — not the broken multi-chunk ESM pin.
function getChart() {
  if (typeof window !== "undefined" && window.Chart) return window.Chart
  throw new Error("Chart.js UMD not loaded (window.Chart missing)")
}

// Renders the performance bar chart from the same series shown in the table.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { payload: String }

  connect() {
    this.render()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  render() {
    if (!this.hasCanvasTarget) return

    let data
    try {
      data = JSON.parse(this.payloadValue)
    } catch (e) {
      console.error("Invalid chart payload", e)
      return
    }

    if (!data.labels || data.labels.length === 0) return

    const Chart = getChart()
    const styles = getComputedStyle(document.documentElement)
    const pos = styles.getPropertyValue("--color-positive").trim() || "#12b886"
    const neg = styles.getPropertyValue("--color-negative").trim() || "#fa5252"
    const grid = styles.getPropertyValue("--color-grid").trim() || "rgba(148, 163, 184, 0.15)"
    const text = styles.getPropertyValue("--color-muted").trim() || "#94a3b8"
    const partialAlpha = 0.45

    const backgroundColor = data.values.map((v, i) => {
      const base = v >= 0 ? pos : neg
      if (data.partial && data.partial[i]) {
        return this.withAlpha(base, partialAlpha)
      }
      return base
    })

    if (this.chart) this.chart.destroy()

    this.chart = new Chart(this.canvasTarget.getContext("2d"), {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [
          {
            label: "Return %",
            data: data.values,
            backgroundColor,
            borderRadius: 6,
            borderSkipped: false,
            maxBarThickness: 42
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 650,
          easing: "easeOutQuart"
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.92)",
            titleFont: { family: "'IBM Plex Sans', sans-serif", size: 13 },
            bodyFont: { family: "'IBM Plex Mono', monospace", size: 12 },
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => {
                const val = ctx.parsed.y
                const sign = val > 0 ? "+" : ""
                const partial =
                  data.partial && data.partial[ctx.dataIndex] ? " (YTD)" : ""
                return ` ${sign}${val.toFixed(2)}%${partial}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: {
              color: text,
              font: { family: "'IBM Plex Sans', sans-serif", size: 11 }
            },
            border: { display: false }
          },
          y: {
            grid: { color: grid, drawBorder: false },
            ticks: {
              color: text,
              font: { family: "'IBM Plex Mono', monospace", size: 11 },
              callback: (value) => `${value}%`
            },
            border: { display: false }
          }
        }
      }
    })
  }

  withAlpha(color, alpha) {
    if (color.startsWith("#") && color.length === 7) {
      const r = parseInt(color.slice(1, 3), 16)
      const g = parseInt(color.slice(3, 5), 16)
      const b = parseInt(color.slice(5, 7), 16)
      return `rgba(${r}, ${g}, ${b}, ${alpha})`
    }
    return color
  }
}
