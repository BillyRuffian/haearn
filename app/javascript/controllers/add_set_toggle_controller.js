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
  static targets = ["button", "form", "editingForm"]

  connect() {
    this.addFormOpen = false
    this.boundHide = this.hide.bind(this)
    this.observer = new MutationObserver(() => this.syncVisibility())
    window.addEventListener("set-logged", this.boundHide)
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.syncVisibility()
  }

  disconnect() {
    window.removeEventListener("set-logged", this.boundHide)
    this.observer?.disconnect()
    this.setFabVisibility(false)
  }

  show() {
    this.addFormOpen = true
    this.syncVisibility()

    // Focus the first visible input
    const firstInput = this.formTarget.querySelector("input[type='number']:not([type='hidden'])")
    if (firstInput) {
      requestAnimationFrame(() => firstInput.focus())
    }
  }

  hide() {
    if (!this.hasFormTarget || !this.hasButtonTarget) return
    this.addFormOpen = false
    this.syncVisibility()
  }

  editingFormTargetConnected() {
    this.syncVisibility()
  }

  editingFormTargetDisconnected() {
    this.syncVisibility()
  }

  syncVisibility() {
    if (!this.hasFormTarget || !this.hasButtonTarget) return

    const editingActive = this.editingActive()
    this.formTarget.classList.toggle("d-none", !this.addFormOpen)
    this.buttonTarget.classList.toggle("d-none", this.addFormOpen || editingActive)
    this.setFabVisibility(this.addFormOpen || editingActive)
  }

  editingActive() {
    return this.element.querySelector("[data-add-set-toggle-target='editingForm']") !== null
  }

  setFabVisibility(hidden) {
    document.body.classList.toggle("add-set-form-open", hidden)
  }
}
