import { Controller } from "@hotwired/stimulus"

// Debounced search-as-you-type
// Add data-controller="search" to a form
// Add data-search-target="input" to the search field
// Add data-action="input->search#search" to trigger on typing
export default class extends Controller {
  static targets = ["input", "form"]
  static values = {
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search() {
    // Clear any pending search
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Debounce the search
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.delayValue)
  }

  submitForm() {
    // Find the form - either the element itself or a target
    const form = this.element.tagName === "FORM" ? this.element : this.formTarget

    // Use requestSubmit to trigger Turbo properly
    if (form.requestSubmit) {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }
}
