import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="set-form"
export default class extends Controller {
  static targets = ["weight", "reps", "submit"]

  connect() {
    // Listen for successful turbo submissions to trigger rest timer
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.handleSubmitEnd.bind(this))
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      // Find the block's rest seconds from the nearest workout-block ancestor
      const block = this.element.closest(".workout-block")
      const blockRestController = block?.querySelector("[data-controller~='block-rest']")
      const restSeconds = blockRestController ? parseInt(blockRestController.dataset.blockRestSecondsValue, 10) : null

      // Dispatch custom event for rest timer with block-specific rest duration
      window.dispatchEvent(new CustomEvent("set-logged", {
        bubbles: true,
        detail: { restSeconds }
      }))
    }
  }

  submitted() {
    // No-op: fields are prepopulated by the server via Turbo Stream replacement
  }
}
