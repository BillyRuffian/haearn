import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="muscle-group-chart"
export default class extends Controller {
  static targets = ["canvas", "periodSelect"]
  static values = {
    sevenDays: Object,
    thirtyDays: Object,
    colors: Object,
    labels: Object,
    unit: { type: String, default: "kg·reps" }
  }

  connect() {
    this.currentPeriod = "seven_days"
    this.createChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  createChart() {
    const ctx = this.canvasTarget.getContext("2d")
    const data = this.getDataForPeriod(this.currentPeriod)

    this.chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [{
          data: data.values,
          backgroundColor: data.colors,
          borderColor: "#1a1a1a",
          borderWidth: 2,
          hoverBorderColor: "#fff",
          hoverBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        animation: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? false : { duration: 250 },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: "rgba(255, 255, 255, 0.06)" },
            ticks: { color: "#b0b0b0", maxTicksLimit: 5 }
          },
          y: {
            grid: { display: false },
            ticks: { color: "#d0d0d0", font: { size: 12 } }
          }
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#1a1a1a",
            titleColor: "#e0e0e0",
            bodyColor: "#e0e0e0",
            borderColor: "#333",
            borderWidth: 1,
            padding: 12,
            displayColors: true,
            callbacks: {
              label: (context) => {
                const value = context.parsed.x
                const total = context.dataset.data.reduce((a, b) => a + b, 0)
                const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : "0.0"
                return ` ${this.formatNumber(value)} ${this.unitValue} · ${percentage}%`
              }
            }
          }
        }
      }
    })
  }

  getDataForPeriod(period) {
    const rawData = period === "seven_days" ? this.sevenDaysValue : this.thirtyDaysValue
    const colors = this.colorsValue
    const labelMap = this.labelsValue

    const labels = []
    const values = []
    const chartColors = []

    const entries = Object.entries(rawData)
      .filter(([, volume]) => volume > 0)
      .sort((a, b) => b[1] - a[1])

    entries.forEach(([muscleGroup, volume]) => {
      labels.push(labelMap[muscleGroup] || muscleGroup)
      values.push(volume)
      chartColors.push(colors[muscleGroup] || "#71797E")
    })

    return { labels, values, colors: chartColors }
  }

  changePeriod(event) {
    this.currentPeriod = event.target.value
    this.updateChart()
  }

  updateChart() {
    const data = this.getDataForPeriod(this.currentPeriod)

    this.chart.data.labels = data.labels
    this.chart.data.datasets[0].data = data.values
    this.chart.data.datasets[0].backgroundColor = data.colors
    this.chart.update("none")
  }

  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + "M"
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + "k"
    }
    return num.toLocaleString()
  }
}
