import { Controller } from "@hotwired/stimulus"

// Handles the date overlay on progress photos
// Currently a placeholder for future enhancements (toggle overlay, etc.)
// Connects to data-controller="photo-overlay"
export default class extends Controller {
  static targets = ["image"]

  connect() {
    // Future: toggle overlay visibility, download with overlay baked in, etc.
  }
}
