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
      // Dispatch custom event for rest timer
      window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))
    }
  }

  submitted() {
    // No-op: fields are prepopulated by the server via Turbo Stream replacement
  }
}
