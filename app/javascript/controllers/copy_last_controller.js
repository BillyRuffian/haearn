import { Controller } from "@hotwired/stimulus"

// Populates set form fields from previous session data
// Connects to data-controller="copy-last"
export default class extends Controller {
  static values = {
    payload: Object
  }

  copy() {
    const form = this.element.closest("form") || this.element.closest(".add-set-form")?.querySelector("form") || this.element.closest("[data-controller~='set-form']")?.closest("form")
    if (!form || !this.hasPayloadValue) return

    Object.entries(this.payloadValue).forEach(([key, value]) => {
      this.applyFieldValue(form, key, value)
    })
  }

  applyFieldValue(form, key, value) {
    const checkboxField = form.querySelector(`[name='exercise_set[${key}]'][type='checkbox']`)
    if (checkboxField) {
      checkboxField.checked = Boolean(value)
      checkboxField.dispatchEvent(new Event("change", { bubbles: true }))
      return
    }

    const field = form.querySelector(`[name='exercise_set[${key}]']:not([type='hidden'])`)
    if (!field) return

    field.value = value == null ? "" : String(value)
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
