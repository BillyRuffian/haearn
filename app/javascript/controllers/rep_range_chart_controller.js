import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Rep Range Distribution Chart
// Bar chart showing percentage of sets in each rep range
// Helps lifters ensure training variety (strength 1-5, hypertrophy 6-12, endurance 13+)
export default class extends Controller {
  static values = {
    data: Object // { "1-5": count, "6-10": count, "11-15": count, "16+": count }
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
    if (!this.hasCanvasTarget || !this.dataValue) return

    const data = this.dataValue
    const total = Object.values(data).reduce((a, b) => a + b, 0)
    
    if (total === 0) return

    // Define rep ranges with labels and colors
    const ranges = [
      { key: '1-5', label: 'Strength (1-5)', color: '#a33a0c', description: 'Heavy / Strength' },
      { key: '6-10', label: 'Hypertrophy (6-10)', color: '#ff6b35', description: 'Size / Hypertrophy' },
      { key: '11-15', label: 'Endurance (11-15)', color: '#f0a060', description: 'Muscular Endurance' },
      { key: '16+', label: 'High Rep (16+)', color: '#71797E', description: 'High Rep / Conditioning' }
    ]

    const labels = ranges.map(r => r.label)
    const values = ranges.map(r => data[r.key] || 0)
    const percentages = values.map(v => ((v / total) * 100).toFixed(1))
    const colors = ranges.map(r => r.color)

    const ctx = this.canvasTarget.getContext("2d")

    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors,
          borderColor: colors.map(c => c),
          borderWidth: 1,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
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
            cornerRadius: 4,
            callbacks: {
              label: (context) => {
                const idx = context.dataIndex
                const count = values[idx]
                const pct = percentages[idx]
                return `${count} sets (${pct}%)`
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 }
            },
            title: {
              display: true,
              text: 'Number of Sets',
              color: '#6a6a6a',
              font: { size: 11 }
            }
          },
          y: {
            grid: {
              display: false
            },
            ticks: {
              color: "#8a8a8a",
              font: { size: 11 }
            }
          }
        }
      }
    })
  }
}
