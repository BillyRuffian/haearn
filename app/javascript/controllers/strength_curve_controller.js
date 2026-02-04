import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="strength-curve"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Array
  }

  // Color palette for different exercises
  colors = [
    { bg: "rgba(255, 107, 53, 0.2)", border: "#ff6b35" },   // Rust orange
    { bg: "rgba(78, 205, 196, 0.2)", border: "#4ECDC4" },   // Teal
    { bg: "rgba(69, 183, 209, 0.2)", border: "#45B7D1" },   // Sky blue
    { bg: "rgba(150, 206, 180, 0.2)", border: "#96CEB4" },  // Sage green
    { bg: "rgba(187, 143, 206, 0.2)", border: "#BB8FCE" }   // Light purple
  ]

  connect() {
    this.createChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  createChart() {
    const ctx = this.canvasTarget.getContext("2d")
    const exercises = this.dataValue

    if (!exercises || exercises.length === 0) return

    const repRanges = ["1-3", "4-6", "7-10", "11-15"]

    const datasets = exercises.map((exercise, index) => {
      const color = this.colors[index % this.colors.length]
      const data = repRanges.map(range => exercise.ranges[range] || null)

      return {
        label: exercise.name,
        data: data,
        fill: false,
        backgroundColor: color.bg,
        borderColor: color.border,
        pointBackgroundColor: color.border,
        pointBorderColor: "#fff",
        pointHoverBackgroundColor: "#fff",
        pointHoverBorderColor: color.border,
        borderWidth: 2,
        pointRadius: 5,
        pointHoverRadius: 7,
        tension: 0.3,
        spanGaps: true
      }
    })

    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: repRanges.map(r => r + " reps"),
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        scales: {
          x: {
            grid: {
              color: "rgba(255, 255, 255, 0.1)"
            },
            ticks: {
              color: "#9e9e9e"
            }
          },
          y: {
            grid: {
              color: "rgba(255, 255, 255, 0.1)"
            },
            ticks: {
              color: "#9e9e9e"
            },
            title: {
              display: true,
              text: "Max Weight",
              color: "#9e9e9e"
            }
          }
        },
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              color: "#e0e0e0",
              padding: 15,
              usePointStyle: true,
              pointStyle: "circle"
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
                const value = context.parsed.y
                if (value === null) return ` ${context.dataset.label}: No data`
                return ` ${context.dataset.label}: ${value}`
              }
            }
          }
        }
      }
    })
  }
}
