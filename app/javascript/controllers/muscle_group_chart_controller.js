import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="muscle-group-chart"
export default class extends Controller {
  static targets = ["canvas", "periodSelect"]
  static values = {
    sevenDays: Object,
    thirtyDays: Object,
    colors: Object,
    labels: Object
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
      type: "doughnut",
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
        cutout: "60%",
        plugins: {
          legend: {
            display: true,
            position: 'right',
            labels: {
              color: '#8a8a8a',
              font: { size: 11 },
              padding: 10,
              boxWidth: 12,
              boxHeight: 12,
              usePointStyle: true,
              pointStyle: 'circle'
            }
          },
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
                const value = context.parsed
                const total = context.dataset.data.reduce((a, b) => a + b, 0)
                const percentage = ((value / total) * 100).toFixed(1)
                return ` ${this.formatNumber(value)} (${percentage}%)`
              }
            }
          }
        },
        animation: {
          animateRotate: true,
          animateScale: true
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

    Object.entries(rawData).forEach(([muscleGroup, volume]) => {
      if (volume > 0) {
        labels.push(labelMap[muscleGroup] || muscleGroup)
        values.push(volume)
        chartColors.push(colors[muscleGroup] || "#71797E")
      }
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
    this.chart.update("active")
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
