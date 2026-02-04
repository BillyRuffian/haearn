import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "display"]

  connect() {
    this.updateDisplay()
  }

  updateDisplay() {
    const seconds = parseInt(this.sliderTarget.value)
    this.displayTarget.textContent = this.formatSeconds(seconds)
  }

  formatSeconds(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes}:${seconds.toString().padStart(2, '0')}`
  }
}
