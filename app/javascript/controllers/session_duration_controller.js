import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Session Duration Trend Chart
// Line chart showing workout duration over time
// Helps identify if workouts are getting longer/shorter
export default class extends Controller {
  static values = {
    data: Array // Array of { date: string, duration: number, gym: string }
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
    
    // Transform data for Chart.js
    const chartData = data.map(d => ({
      x: new Date(d.date),
      y: d.duration,
      gym: d.gym
    }))

    // Calculate average for reference line
    const avgDuration = data.reduce((sum, d) => sum + d.duration, 0) / data.length

    const ctx = this.canvasTarget.getContext("2d")

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        datasets: [
          {
            label: 'Duration (min)',
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
          }
        ]
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
                const raw = items[0].raw
                return raw.gym
              },
              label: (context) => {
                const raw = context.raw
                const date = new Date(raw.x).toLocaleDateString('en-US', { 
                  month: 'short', 
                  day: 'numeric'
                })
                return `${raw.y} min on ${date}`
              },
              afterBody: () => {
                return `Avg: ${Math.round(avgDuration)} min`
              }
            }
          },
          annotation: {
            annotations: {
              avgLine: {
                type: 'line',
                yMin: avgDuration,
                yMax: avgDuration,
                borderColor: 'rgba(113, 121, 126, 0.5)',
                borderWidth: 1,
                borderDash: [5, 5]
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'day',
              displayFormats: {
                day: 'MMM d'
              }
            },
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 },
              maxRotation: 45,
              maxTicksLimit: 8
            }
          },
          y: {
            min: 0,
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 },
              callback: (value) => `${value}m`
            },
            title: {
              display: true,
              text: 'Duration',
              color: '#6a6a6a',
              font: { size: 11 }
            }
          }
        }
      }
    })
  }
}
