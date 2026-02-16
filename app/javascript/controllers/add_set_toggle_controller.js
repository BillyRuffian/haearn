import { Controller } from "@hotwired/stimulus"

// Toggles visibility of the add-set form behind an "Add Set" button.
// The form is hidden by default; tapping the button reveals it.
// After a successful set submission, the "set-logged" custom event
// (dispatched by set_form_controller) triggers re-hiding the form.
//
// Usage:
//   <div data-controller="add-set-toggle">
//     <button data-add-set-toggle-target="button" data-action="add-set-toggle#show">+ Add Set</button>
//     <div data-add-set-toggle-target="form" class="d-none">
//       ... form content ...
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["button", "form"]

  connect() {
    this.boundHide = this.hide.bind(this)
    window.addEventListener("set-logged", this.boundHide)
  }

  disconnect() {
    window.removeEventListener("set-logged", this.boundHide)
    this.setFabVisibility(false)
  }

  show() {
    this.buttonTarget.classList.add("d-none")
    this.formTarget.classList.remove("d-none")
    this.setFabVisibility(true)

    // Focus the first visible input
    const firstInput = this.formTarget.querySelector("input[type='number']:not([type='hidden'])")
    if (firstInput) {
      requestAnimationFrame(() => firstInput.focus())
    }
  }

  hide() {
    if (!this.hasFormTarget || !this.hasButtonTarget) return
    this.formTarget.classList.add("d-none")
    this.buttonTarget.classList.remove("d-none")
    this.setFabVisibility(false)
  }

  setFabVisibility(hidden) {
    document.body.classList.toggle("add-set-form-open", hidden)
  }
}
