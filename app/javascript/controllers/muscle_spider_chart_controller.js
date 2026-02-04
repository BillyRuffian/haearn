import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Muscle Volume Spider/Radar Chart
// Shows which muscle groups have been trained and their relative volume
export default class extends Controller {
  static targets = ["canvas", "periodSelect"]
  static values = {
    sevenDays: Object,
    thirtyDays: Object,
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

  periodChanged(event) {
    this.currentPeriod = event.target.value
    this.updateChart()
  }

  createChart() {
    const ctx = this.canvasTarget.getContext("2d")
    const data = this.getDataForPeriod(this.currentPeriod)

    // Define all muscle groups we want to show
    const muscleGroups = [
      'chest', 'back', 'shoulders', 'biceps', 'triceps',
      'quadriceps', 'hamstrings', 'glutes', 'calves', 'core'
    ]
    
    const labelMap = this.labelsValue
    const labels = muscleGroups.map(m => labelMap[m] || m.charAt(0).toUpperCase() + m.slice(1))
    const values = muscleGroups.map(m => data[m] || 0)
    
    // Normalize values to percentage of max for better visualization
    const maxValue = Math.max(...values, 1)

    this.chart = new Chart(ctx, {
      type: "radar",
      data: {
        labels: labels,
        datasets: [{
          label: 'Volume',
          data: values,
          backgroundColor: 'rgba(255, 107, 53, 0.25)',
          borderColor: '#ff6b35',
          borderWidth: 2,
          pointBackgroundColor: '#ff6b35',
          pointBorderColor: '#1a1a1a',
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6
        }]
      },
      options: {
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
            cornerRadius: 4,
            callbacks: {
              label: (context) => {
                return `${this.formatNumber(context.parsed.r)}`
              }
            }
          }
        },
        scales: {
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
              display: false,
              stepSize: maxValue / 4
            },
            suggestedMin: 0,
            suggestedMax: maxValue * 1.1
          }
        }
      }
    })
  }

  updateChart() {
    const data = this.getDataForPeriod(this.currentPeriod)
    
    const muscleGroups = [
      'chest', 'back', 'shoulders', 'biceps', 'triceps',
      'quadriceps', 'hamstrings', 'glutes', 'calves', 'core'
    ]
    
    const values = muscleGroups.map(m => data[m] || 0)
    const maxValue = Math.max(...values, 1)

    this.chart.data.datasets[0].data = values
    this.chart.options.scales.r.suggestedMax = maxValue * 1.1
    this.chart.options.scales.r.ticks.stepSize = maxValue / 4
    this.chart.update()
  }

  getDataForPeriod(period) {
    return period === "seven_days" ? this.sevenDaysValue : this.thirtyDaysValue
  }

  formatNumber(num) {
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'k'
    }
    return num.toLocaleString()
  }
}
