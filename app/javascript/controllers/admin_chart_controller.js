import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    labels: Array,
    data: Array
  }

  async connect() {
    const { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip } = await import("chart.js")
    Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

    this.chart = new Chart(this.element, {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: [{
          data: this.dataValue,
          backgroundColor: "rgba(163, 58, 12, 0.7)",
          borderColor: "rgba(201, 77, 20, 1)",
          borderWidth: 1,
          borderRadius: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#1e1e1e",
            titleColor: "#c8c8c8",
            bodyColor: "#c8c8c8",
            borderColor: "#333",
            borderWidth: 1
          }
        },
        scales: {
          x: {
            grid: { color: "rgba(255,255,255,0.05)" },
            ticks: { color: "#666", font: { size: 10 } }
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(255,255,255,0.05)" },
            ticks: { color: "#666", stepSize: 1 }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
