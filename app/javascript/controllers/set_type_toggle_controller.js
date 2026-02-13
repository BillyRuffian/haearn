import { Controller } from "@hotwired/stimulus"

// Handles set type selection and tempo field visibility
// Connects to data-controller="set-type-toggle"
export default class extends Controller {
  static targets = ["tempoRow", "tempoToggle"]

  connect() {
    this.tempoVisible = false
  }

  toggleTempo() {
    this.tempoVisible = !this.tempoVisible

    if (this.hasTempoRowTarget) {
      this.tempoRowTarget.classList.toggle("d-none", !this.tempoVisible)
    }

    if (this.hasTempoToggleTarget) {
      const icon = this.tempoToggleTarget.querySelector(".bi-chevron-down, .bi-chevron-up")
      if (icon) {
        icon.classList.toggle("bi-chevron-down", !this.tempoVisible)
        icon.classList.toggle("bi-chevron-up", this.tempoVisible)
      }
    }
  }

  // Called when set type changes (currently no-op, but available for future use)
  toggle() {
    // Could show/hide specific fields based on set type
  }
}
