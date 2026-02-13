import { Controller } from "@hotwired/stimulus"

// Percentage-based programming calculator
// Given an e1RM, calculates working weight at a specified percentage
export default class extends Controller {
  static targets = ["percentage", "result"]
  static values = {
    e1rm: Number,    // e1RM in user's display unit
    unit: String     // kg or lbs
  }

  connect() {
    this.updateResult()
  }

  calculate() {
    this.updateResult()
  }

  applyWeight() {
    const weight = this.calculatedWeight()
    if (!weight) return

    // The weight field and this calculator are siblings inside the same parent container div.
    // Walk up until we find a container that has the weight input field.
    let container = this.element.parentElement
    while (container) {
      const weightField = container.querySelector("[name*='weight_value']")
      if (weightField) {
        weightField.value = weight
        weightField.dispatchEvent(new Event("input", { bubbles: true }))
        return
      }
      container = container.parentElement
    }
  }

  updateResult() {
    if (!this.hasResultTarget || !this.hasPercentageTarget) return

    const weight = this.calculatedWeight()
    if (weight) {
      this.resultTarget.textContent = `${weight} ${this.unitValue}`
      this.resultTarget.classList.remove("d-none")
    } else {
      this.resultTarget.textContent = ""
    }
  }

  calculatedWeight() {
    const pct = parseInt(this.percentageTarget.value)
    if (!pct || pct <= 0 || pct > 100 || !this.e1rmValue) return null

    // weight = e1RM * (percentage / 100), rounded to nearest 2.5 (kg) or 5 (lbs)
    const raw = this.e1rmValue * (pct / 100.0)
    const step = this.unitValue === "lbs" ? 5 : 2.5
    return Math.round(raw / step) * step
  }
}
