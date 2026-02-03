import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="timer"
export default class extends Controller {
  static values = { startedAt: String }
  static targets = ["display"]

  connect() {
    this.startTime = new Date(this.startedAtValue)
    this.updateDisplay()
    this.interval = setInterval(() => this.updateDisplay(), 60000) // Update every minute
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateDisplay() {
    const now = new Date()
    const diffMs = now - this.startTime
    const minutes = Math.floor(diffMs / 60000)

    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = minutes
    }
  }
}
