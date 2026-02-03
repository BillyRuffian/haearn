import { Controller } from "@hotwired/stimulus"

// Loading state controller
// Shows loading overlay/spinner during Turbo navigations or form submissions
//
// Usage:
//   <div data-controller="loading" data-loading-target="container">
//     <div data-loading-target="spinner" class="loading-overlay d-none">
//       <div class="loading-spinner"></div>
//     </div>
//     <!-- Content -->
//   </div>
//
// Or for buttons:
//   <button data-controller="loading"
//           data-action="click->loading#start turbo:submit-end@window->loading#stop">
//     <span data-loading-target="text">Save</span>
//     <span data-loading-target="spinner" class="d-none">
//       <span class="spinner-border spinner-border-sm"></span>
//     </span>
//   </button>
//
export default class extends Controller {
  static targets = ["spinner", "text", "container"]
  static values = {
    disableOnLoad: { type: Boolean, default: true }
  }

  connect() {
    // Listen for Turbo events
    this.boundStart = this.start.bind(this)
    this.boundStop = this.stop.bind(this)

    document.addEventListener("turbo:submit-start", this.boundStart)
    document.addEventListener("turbo:submit-end", this.boundStop)
    document.addEventListener("turbo:before-fetch-request", this.boundStart)
    document.addEventListener("turbo:before-fetch-response", this.boundStop)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.boundStart)
    document.removeEventListener("turbo:submit-end", this.boundStop)
    document.removeEventListener("turbo:before-fetch-request", this.boundStart)
    document.removeEventListener("turbo:before-fetch-response", this.boundStop)
  }

  start(event) {
    // Only handle events from this element or its descendants
    if (event && event.target && !this.element.contains(event.target)) return

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("d-none")
    }

    if (this.hasTextTarget) {
      this.textTarget.classList.add("d-none")
    }

    if (this.disableOnLoadValue && this.element.tagName === "BUTTON") {
      this.element.disabled = true
    }

    this.dispatch("started")
  }

  stop(event) {
    // Only handle events from this element or its descendants
    if (event && event.target && !this.element.contains(event.target)) return

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("d-none")
    }

    if (this.hasTextTarget) {
      this.textTarget.classList.remove("d-none")
    }

    if (this.disableOnLoadValue && this.element.tagName === "BUTTON") {
      this.element.disabled = false
    }

    this.dispatch("stopped")
  }

  toggle() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.toggle("d-none")
    }
  }
}
