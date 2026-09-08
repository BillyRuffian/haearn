import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// PR Timeline - Scatter plot showing when PRs were hit across all lifts
// Each exact exercise/equipment context gets a row; x-axis is time and every event marker has equal radius
export default class extends Controller {
  static values = {
    data: Array,
    unit: { type: String, default: "kg" },
    volumeUnit: { type: String, default: "kg·reps" }
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
    const exercises = [...new Set(prData.map(pr => pr.context || pr.exercise))]
    const exerciseIndex = Object.fromEntries(exercises.map((e, i) => [e, i]))
    
    // Group PRs by type for different colors
    const weightPRs = prData.filter(pr => pr.type === 'weight')
    const volumePRs = prData.filter(pr => pr.type === 'volume')
    
    const toScatterData = (prs) => prs.map(pr => ({
      x: new Date(pr.date).getTime(),
      y: exerciseIndex[pr.context || pr.exercise],
      r: 7,
      exercise: pr.exercise,
      context: pr.context || pr.exercise,
      weight: pr.weight,
      reps: pr.reps,
      setLoadVolume: pr.set_load_volume,
      type: pr.type,
      date: pr.date
    }))

    const ctx = this.canvasTarget.getContext("2d")
    
    // Calculate min/max for x-axis with padding
    const allX = [...toScatterData(weightPRs), ...toScatterData(volumePRs)].map(d => d.x)
    const xMin = Math.min(...allX)
    const xMax = Math.max(...allX)
    const xPadding = (xMax - xMin) * 0.1 || 86400000 * 7 // 7 days padding if single point

    this.chart = new Chart(ctx, {
      type: 'bubble',
      data: {
        datasets: [
          {
            label: 'Heavier set',
            data: toScatterData(weightPRs),
            backgroundColor: 'rgba(255, 107, 53, 0.7)',
            borderColor: '#ff6b35',
            borderWidth: 1
          },
          {
            label: 'Best set load',
            data: toScatterData(volumePRs),
            backgroundColor: 'rgba(184, 134, 11, 0.7)',
            borderColor: '#b8860b',
            borderWidth: 1
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? false : { duration: 250 },
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
                return raw.context
              },
              label: (context) => {
                const raw = context.raw
                const date = new Date(raw.date).toLocaleDateString('en-US', { 
                  month: 'short', 
                  day: 'numeric', 
                  year: 'numeric' 
                })
                const metric = raw.type === 'weight'
                  ? `Heavier set: ${raw.weight} ${this.unitValue} × ${raw.reps}`
                  : `Best set load: ${raw.setLoadVolume} ${this.volumeUnitValue}`
                return [metric, date]
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
              color: "#b0b0b0",
              font: { size: 12 },
              maxRotation: 0,
              maxTicksLimit: window.innerWidth < 576 ? 4 : 8,
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
              color: "#c4c4c4",
              font: { size: 12 },
              stepSize: 1,
              callback: (value) => {
                const idx = Math.round(value)
                const label = exercises[idx] || ''
                return window.innerWidth < 576 && label.length > 22 ? `${label.slice(0, 20)}…` : label
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
