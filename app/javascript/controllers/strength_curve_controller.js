import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="strength-curve"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Array,
    unit: { type: String, default: "kg" }
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

    this.selectedIndex = 0
    const repRanges = ["1-3", "4-6", "7-10", "11-15"]
    const selected = exercises[this.selectedIndex]
    const color = this.colors[0]
    const datasets = [{
      label: selected.name,
      data: repRanges.map(range => selected.ranges[range] || null),
      backgroundColor: color.border,
      borderColor: color.border,
      borderWidth: 1,
      borderRadius: 5
    }]

    this.chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: repRanges.map(r => r + " reps"),
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? false : { duration: 250 },
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
              color: "#b0b0b0"
            }
          },
          y: {
            grid: {
              color: "rgba(255, 255, 255, 0.1)"
            },
            ticks: {
              color: "#b0b0b0"
            },
            title: {
              display: true,
              text: `Max Weight (${this.unitValue})`,
              color: "#b0b0b0"
            }
          }
        },
        plugins: {
          legend: {
            display: false
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
                return ` ${context.dataset.label}: ${value} ${this.unitValue}`
              }
            }
          }
        }
      }
    })
  }

  changeContext(event) {
    if (!this.chart) return

    this.selectedIndex = Number(event.target.value)
    const exercise = this.dataValue[this.selectedIndex]
    const repRanges = ["1-3", "4-6", "7-10", "11-15"]
    this.chart.data.datasets[0].label = exercise.name
    this.chart.data.datasets[0].data = repRanges.map(range => exercise.ranges[range] || null)
    this.chart.update("none")
  }
}
