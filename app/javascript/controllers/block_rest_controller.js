import { Controller } from "@hotwired/stimulus"

// Per-block rest timer configuration
// Adjusts rest_seconds on a workout block and communicates with the rest timer
export default class extends Controller {
  static targets = ["display"]
  static values = {
    url: String,
    seconds: Number,
    blockId: Number
  }

  connect() {
    this.updateDisplay()
  }

  increase() {
    this.secondsValue = Math.min(this.secondsValue + 15, 600)
    this.save()
  }

  decrease() {
    this.secondsValue = Math.max(this.secondsValue - 15, 15)
    this.save()
  }

  updateDisplay() {
    if (this.hasDisplayTarget) {
      const mins = Math.floor(this.secondsValue / 60)
      const secs = this.secondsValue % 60
      this.displayTarget.textContent = `${mins}:${secs.toString().padStart(2, "0")}`
    }
  }

  save() {
    this.updateDisplay()

    // Update the rest timer footer duration if it exists
    const restTimer = document.querySelector("[data-controller~='rest-timer']")
    if (restTimer) {
      restTimer.dataset.restTimerDurationValue = this.secondsValue.toString()
      // Dispatch event so rest timer picks up the change
      restTimer.dispatchEvent(new CustomEvent("rest-duration-changed", {
        detail: { seconds: this.secondsValue, blockId: this.blockIdValue }
      }))
    }

    // Persist to server
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      body: `block_id=${this.blockIdValue}&rest_seconds=${this.secondsValue}`
    })
  }
}
