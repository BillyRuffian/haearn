import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Estimated 1RM Trend Chart
// Tracks estimated one-rep max over time using Epley formula: 1RM = weight × (1 + reps/30)
// More meaningful than raw weight as it normalizes across rep ranges
export default class extends Controller {
  static values = {
    data: Array // Array of { date: string, e1rm: number, weight: number, reps: number }
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
    if (!this.hasCanvasTarget || !this.dataValue?.length) return

    const data = this.dataValue
    
    // Transform data for Chart.js time series
    const chartData = data.map(d => ({
      x: new Date(d.date),
      y: d.e1rm,
      weight: d.weight,
      reps: d.reps
    }))

    const ctx = this.canvasTarget.getContext("2d")

    // Calculate min/max for better axis scaling
    const e1rmValues = data.map(d => d.e1rm)
    const minE1rm = Math.min(...e1rmValues)
    const maxE1rm = Math.max(...e1rmValues)
    const padding = (maxE1rm - minE1rm) * 0.1 || 10

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        datasets: [{
          label: 'Estimated 1RM',
          data: chartData,
          backgroundColor: 'rgba(255, 107, 53, 0.2)',
          borderColor: '#ff6b35',
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: '#ff6b35',
          pointBorderColor: '#1a1a1a',
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
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
              title: (items) => {
                if (!items.length) return ''
                const date = new Date(items[0].raw.x)
                return date.toLocaleDateString('en-US', { 
                  month: 'short', 
                  day: 'numeric', 
                  year: 'numeric' 
                })
              },
              label: (context) => {
                const raw = context.raw
                return [
                  `Est. 1RM: ${raw.y.toFixed(1)}`,
                  `From: ${raw.weight} × ${raw.reps} reps`
                ]
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'week',
              displayFormats: {
                week: 'MMM d'
              }
            },
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 },
              maxRotation: 45
            }
          },
          y: {
            min: Math.max(0, minE1rm - padding),
            max: maxE1rm + padding,
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 }
            },
            title: {
              display: true,
              text: 'Est. 1RM',
              color: '#6a6a6a',
              font: { size: 11 }
            }
          }
        }
      }
    })
  }
}
