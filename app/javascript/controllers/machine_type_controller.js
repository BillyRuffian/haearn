import { Controller } from "@hotwired/stimulus"

// Controls visibility of cable ratio field based on equipment type
export default class extends Controller {
  static targets = ["ratioField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const select = this.element
    const isCables = select.value === "cables"

    // Find the ratio field in the form
    const form = this.element.closest("form")
    const ratioField = form.querySelector('[data-machine-type-target="ratioField"]')

    if (ratioField) {
      ratioField.style.display = isCables ? "" : "none"
    }
  }
}
