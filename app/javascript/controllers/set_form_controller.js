import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="set-form"
export default class extends Controller {
  static targets = ["weight", "reps", "submit"]

  connect() {
    // Listen for successful turbo submissions to trigger rest timer
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
    this.boundHandleOfflineQueued = this.handleOfflineQueued.bind(this)
    this.element.addEventListener("offline-form:queued", this.boundHandleOfflineQueued)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
    this.element.removeEventListener("offline-form:queued", this.boundHandleOfflineQueued)
  }

  handleOfflineQueued() {
    window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))
    }
  }

  submitted() {
    // No-op: fields are prepopulated by the server via Turbo Stream replacement
  }
}
