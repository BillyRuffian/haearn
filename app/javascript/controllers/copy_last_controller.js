import { Controller } from "@hotwired/stimulus"

// Populates set form fields from previous session data
// Connects to data-controller="copy-last"
export default class extends Controller {
  static values = {
    weight: String,
    reps: String,
    duration: String,
    distance: String
  }

  copy() {
    const form = this.element.closest("form") || this.element.closest(".add-set-form")?.querySelector("form") || this.element.closest("[data-controller~='set-form']")?.closest("form")
    if (!form) return

    if (this.hasWeightValue && this.weightValue) {
      const weightField = form.querySelector("[name*='weight_value']")
      if (weightField) {
        weightField.value = this.weightValue
        weightField.dispatchEvent(new Event("input", { bubbles: true }))
      }
    }

    if (this.hasRepsValue && this.repsValue) {
      const repsField = form.querySelector("[name*='[reps]']")
      if (repsField) repsField.value = this.repsValue
    }

    if (this.hasDurationValue && this.durationValue) {
      const durationField = form.querySelector("[name*='duration_seconds']")
      if (durationField) durationField.value = this.durationValue
    }

    if (this.hasDistanceValue && this.distanceValue) {
      const distanceField = form.querySelector("[name*='distance_meters']")
      if (distanceField) distanceField.value = this.distanceValue
    }
  }
}
