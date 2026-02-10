import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Chart.js controller for rendering progress charts
// Supports two modes:
// 1. Simple mode: data-chart-labels-value, data-chart-points-value, data-chart-label-value, data-chart-color-value
// 2. Advanced mode: data-chart-data-value (full Chart.js data object)
export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    data: Object,
    options: Object,
    // Simple mode values
    labels: Array,
    points: Array,
    label: { type: String, default: "Value" },
    color: { type: String, default: "#c86432" },
    horizontal: { type: Boolean, default: false },
    fill: { type: Boolean, default: false }
  }

  static targets = ["canvas"]

  connect() {
    this.chart = null

    // Configure Chart.js defaults for dark theme
    Chart.defaults.color = "#8a8a8a"
    Chart.defaults.borderColor = "rgba(255, 255, 255, 0.1)"
    Chart.defaults.font.family = "'Inter', sans-serif"

    this.renderChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  renderChart() {
    if (!this.hasCanvasTarget) return

    // Build chart data - support simple mode or full data object
    let chartData = this.dataValue

    // Simple mode: build data from labels/points/color values
    if (this.hasLabelsValue && this.hasPointsValue) {
      const dataset = {
        label: this.labelValue,
        data: this.pointsValue,
        backgroundColor: this.colorValue,
        borderColor: this.colorValue,
        borderWidth: 2
      }
      
      // Radar charts always have fill
      if (this.typeValue === 'radar') {
        dataset.fill = true
        dataset.backgroundColor = this.hexToRgba(this.colorValue, 0.25)
        dataset.pointBackgroundColor = this.colorValue
        dataset.pointBorderColor = '#1a1a1a'
        dataset.pointBorderWidth = 2
        dataset.pointRadius = 4
        dataset.pointHoverRadius = 6
      }
      // Add fill for area charts
      else if (this.fillValue) {
        dataset.fill = true
        dataset.backgroundColor = this.hexToRgba(this.colorValue, 0.2)
      }
      
      chartData = {
        labels: this.labelsValue,
        datasets: [dataset]
      }
    }

    if (!chartData) return

    const ctx = this.canvasTarget.getContext("2d")

    // Default options for dark theme
    let defaultOptions = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          backgroundColor: "rgba(20, 20, 22, 0.95)",
          titleColor: "#fff",
          bodyColor: "#ccc",
          borderColor: "rgba(200, 100, 50, 0.5)",
          borderWidth: 1,
          padding: 12,
          cornerRadius: 4
        }
      },
      elements: {
        line: {
          tension: 0.3,
          borderWidth: 2
        },
        point: {
          radius: 4,
          hoverRadius: 6,
          backgroundColor: "#c86432",
          borderColor: "#c86432"
        }
      }
    }

    // Different scale config for radar vs other charts
    if (this.typeValue === 'radar') {
      defaultOptions.scales = {
        r: {
          angleLines: {
            color: 'rgba(255, 255, 255, 0.1)'
          },
          grid: {
            color: 'rgba(255, 255, 255, 0.1)'
          },
          pointLabels: {
            color: '#8a8a8a',
            font: {
              size: 11,
              weight: '500'
            }
          },
          ticks: {
            color: '#6a6a6a',
            font: {
              size: 10
            },
            backdropColor: 'transparent'
          },
          beginAtZero: true
        }
      }
    } else {
      defaultOptions.scales = {
        x: {
          grid: {
            color: "rgba(255, 255, 255, 0.05)"
          },
          ticks: {
            color: "#6a6a6a",
            font: {
              size: 11
            }
          }
        },
        y: {
          grid: {
            color: "rgba(255, 255, 255, 0.05)"
          },
          ticks: {
            color: "#6a6a6a",
            font: {
              size: 11
            }
          },
          beginAtZero: false
        }
      }
    }

    // Merge with provided options
    const mergedOptions = this.deepMerge(defaultOptions, this.optionsValue || {})
    
    // Handle horizontal bar charts
    let chartType = this.typeValue
    if (this.horizontalValue && chartType === 'bar') {
      mergedOptions.indexAxis = 'y'
      // For horizontal bars, swap x/y grid styling
      mergedOptions.scales.x.beginAtZero = true
      mergedOptions.scales.y.grid = { display: false }
    }

    this.chart = new Chart(ctx, {
      type: chartType,
      data: chartData,
      options: mergedOptions
    })
  }

  // Deep merge helper for options
  deepMerge(target, source) {
    const result = { ...target }
    for (const key in source) {
      if (source[key] && typeof source[key] === "object" && !Array.isArray(source[key])) {
        result[key] = this.deepMerge(target[key] || {}, source[key])
      } else {
        result[key] = source[key]
      }
    }
    return result
  }

  // Convert hex color to rgba
  hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  // Allow updating data dynamically
  dataValueChanged() {
    if (this.chart && this.hasDataValue) {
      this.chart.data = this.dataValue
      this.chart.update()
    }
  }
}
