import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    closeUrl: String
  }

  connect() {
    // Close on Escape key
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Close when clicking the backdrop (the outer div)
  backdropClick(event) {
    // Only close if the click was directly on the backdrop element
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  close() {
    if (this.hasCloseUrlValue) {
      Turbo.visit(this.closeUrlValue, { frame: "modal" })
    }
  }
}
