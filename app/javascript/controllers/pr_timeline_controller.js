import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// PR Timeline - Scatter plot showing when PRs were hit across all lifts
// Each exercise gets a row (y-axis), x-axis is time, point size = relative weight
export default class extends Controller {
  static values = {
    data: Array // Array of { exercise: string, date: string, weight: number, reps: number, type: string }
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

    const prData = this.dataValue
    
    // Get unique exercises and assign y-indices
    const exercises = [...new Set(prData.map(pr => pr.exercise))]
    const exerciseIndex = Object.fromEntries(exercises.map((e, i) => [e, i]))
    
    // Group PRs by type for different colors
    const weightPRs = prData.filter(pr => pr.type === 'weight')
    const volumePRs = prData.filter(pr => pr.type === 'volume')
    
    // Calculate max weight for scaling point sizes
    const maxWeight = Math.max(...prData.map(pr => pr.weight || 0), 1)
    
    // Get date range for labels
    const dates = prData.map(pr => new Date(pr.date))
    const minDate = new Date(Math.min(...dates))
    const maxDate = new Date(Math.max(...dates))
    
    // Create date labels (months between min and max)
    const dateLabels = []
    const current = new Date(minDate.getFullYear(), minDate.getMonth(), 1)
    const end = new Date(maxDate.getFullYear(), maxDate.getMonth() + 1, 1)
    while (current <= end) {
      dateLabels.push(new Date(current))
      current.setMonth(current.getMonth() + 1)
    }
    
    // Transform data for Chart.js bubble format using numeric x values
    const toScatterData = (prs, maxWeight) => prs.map(pr => ({
      x: new Date(pr.date).getTime(),
      y: exerciseIndex[pr.exercise],
      r: Math.max(5, Math.min(18, (pr.weight / maxWeight) * 18)),
      exercise: pr.exercise,
      weight: pr.weight,
      reps: pr.reps,
      type: pr.type,
      date: pr.date
    }))

    const ctx = this.canvasTarget.getContext("2d")
    
    // Calculate min/max for x-axis with padding
    const allX = [...toScatterData(weightPRs, maxWeight), ...toScatterData(volumePRs, maxWeight)].map(d => d.x)
    const xMin = Math.min(...allX)
    const xMax = Math.max(...allX)
    const xPadding = (xMax - xMin) * 0.1 || 86400000 * 7 // 7 days padding if single point

    this.chart = new Chart(ctx, {
      type: 'bubble',
      data: {
        datasets: [
          {
            label: 'Weight PRs',
            data: toScatterData(weightPRs, maxWeight),
            backgroundColor: 'rgba(255, 107, 53, 0.7)',
            borderColor: '#ff6b35',
            borderWidth: 1
          },
          {
            label: 'Volume PRs',
            data: toScatterData(volumePRs, maxWeight),
            backgroundColor: 'rgba(184, 134, 11, 0.7)',
            borderColor: '#b8860b',
            borderWidth: 1
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: {
              color: '#8a8a8a',
              usePointStyle: true,
              pointStyle: 'circle',
              padding: 15
            }
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
                return raw.exercise
              },
              label: (context) => {
                const raw = context.raw
                const date = new Date(raw.date).toLocaleDateString('en-US', { 
                  month: 'short', 
                  day: 'numeric', 
                  year: 'numeric' 
                })
                const typeLabel = raw.type === 'weight' ? 'Weight PR' : 'Volume PR'
                return [
                  `${typeLabel}: ${raw.weight} × ${raw.reps} reps`,
                  date
                ]
              }
            }
          }
        },
        scales: {
          x: {
            type: 'linear',
            min: xMin - xPadding,
            max: xMax + xPadding,
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#6a6a6a",
              font: { size: 11 },
              maxRotation: 45,
              callback: (value) => {
                const date = new Date(value)
                return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
              }
            },
            title: {
              display: false
            }
          },
          y: {
            min: -0.5,
            max: exercises.length - 0.5,
            grid: {
              color: "rgba(255, 255, 255, 0.05)"
            },
            ticks: {
              color: "#8a8a8a",
              font: { size: 10 },
              stepSize: 1,
              callback: (value) => {
                const idx = Math.round(value)
                return exercises[idx] || ''
              }
            },
            title: {
              display: false
            }
          }
        }
      }
    })
  }
}
