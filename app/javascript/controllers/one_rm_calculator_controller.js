import { Controller } from "@hotwired/stimulus"

// 1RM Calculator Controller
// Calculates estimated one-rep max using multiple formulas
export default class extends Controller {
  static targets = ["weight", "reps", "result", "table", "percentageTable"]
  static values = {
    unit: { type: String, default: "kg" }
  }

  connect() {
    this.calculate()
  }

  calculate() {
    const weight = parseFloat(this.weightTarget.value) || 0
    const reps = parseInt(this.repsTarget.value) || 0

    if (weight <= 0 || reps <= 0 || reps > 30) {
      this.resultTarget.innerHTML = this.emptyState()
      if (this.hasTableTarget) this.tableTarget.innerHTML = ""
      if (this.hasPercentageTableTarget) this.percentageTableTarget.innerHTML = ""
      return
    }

    // If reps is 1, 1RM is just the weight
    if (reps === 1) {
      this.resultTarget.innerHTML = this.renderResult(weight, weight, "Actual 1RM")
      this.renderPercentageTable(weight)
      return
    }

    // Calculate using multiple formulas
    const formulas = {
      epley: this.epley(weight, reps),
      brzycki: this.brzycki(weight, reps),
      lombardi: this.lombardi(weight, reps),
      mayhew: this.mayhew(weight, reps),
      oconner: this.oconner(weight, reps),
      wathan: this.wathan(weight, reps)
    }

    const average = Object.values(formulas).reduce((a, b) => a + b, 0) / 6

    this.resultTarget.innerHTML = this.renderResult(weight, average, "Estimated 1RM")

    if (this.hasTableTarget) {
      this.tableTarget.innerHTML = this.renderFormulaTable(formulas)
    }

    this.renderPercentageTable(average)
  }

  // Epley Formula: weight × (1 + reps/30)
  epley(weight, reps) {
    return weight * (1 + reps / 30)
  }

  // Brzycki Formula: weight × (36 / (37 - reps))
  brzycki(weight, reps) {
    if (reps >= 37) return 0
    return weight * (36 / (37 - reps))
  }

  // Lombardi Formula: weight × reps^0.10
  lombardi(weight, reps) {
    return weight * Math.pow(reps, 0.10)
  }

  // Mayhew Formula
  mayhew(weight, reps) {
    return weight / (0.522 + 0.419 * Math.exp(-0.055 * reps))
  }

  // O'Conner Formula: weight × (1 + 0.025 × reps)
  oconner(weight, reps) {
    return weight * (1 + 0.025 * reps)
  }

  // Wathan Formula
  wathan(weight, reps) {
    return weight / (0.4880 + 0.538 * Math.exp(-0.075 * reps))
  }

  emptyState() {
    return `
      <div class="text-center text-muted py-4">
        <i class="bi bi-calculator fs-1 mb-2"></i>
        <p class="mb-0">Enter weight and reps to calculate your estimated 1RM</p>
      </div>
    `
  }

  renderResult(weight, e1rm, label) {
    const unit = this.unitValue
    return `
      <div class="text-center">
        <div class="text-muted small mb-1">${label}</div>
        <div class="display-4 fw-bold text-primary">${Math.round(e1rm)} <small class="text-muted fs-5">${unit}</small></div>
        <div class="text-muted small mt-2">
          Based on ${weight}${unit} × ${this.repsTarget.value} reps
        </div>
      </div>
    `
  }

  renderFormulaTable(formulas) {
    const unit = this.unitValue
    const rows = Object.entries(formulas).map(([name, value]) => `
      <tr>
        <td class="text-capitalize">${name}</td>
        <td class="text-end fw-bold">${Math.round(value)} ${unit}</td>
      </tr>
    `).join("")

    return `
      <table class="table table-sm table-dark mb-0">
        <thead>
          <tr>
            <th>Formula</th>
            <th class="text-end">Estimate</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `
  }

  renderPercentageTable(oneRm) {
    if (!this.hasPercentageTableTarget) return

    const unit = this.unitValue
    const percentages = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]

    const rows = percentages.map(pct => {
      const weight = Math.round(oneRm * pct / 100)
      const estReps = this.repsAtPercentage(pct)
      return `
        <tr>
          <td>${pct}%</td>
          <td class="text-end fw-bold">${weight} ${unit}</td>
          <td class="text-end text-muted">~${estReps} reps</td>
        </tr>
      `
    }).join("")

    this.percentageTableTarget.innerHTML = `
      <table class="table table-sm table-dark mb-0">
        <thead>
          <tr>
            <th>%1RM</th>
            <th class="text-end">Weight</th>
            <th class="text-end">Est. Reps</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `
  }

  // Inverse Epley to estimate reps at a percentage
  repsAtPercentage(percentage) {
    if (percentage >= 100) return 1
    const reps = ((100 / percentage) - 1) * 30
    return Math.max(1, Math.round(reps))
  }

  // Convenience methods for quick adjustments
  incrementWeight(event) {
    const increment = parseFloat(event.params.amount) || 2.5
    this.weightTarget.value = (parseFloat(this.weightTarget.value) || 0) + increment
    this.calculate()
  }

  decrementWeight(event) {
    const decrement = parseFloat(event.params.amount) || 2.5
    const newValue = (parseFloat(this.weightTarget.value) || 0) - decrement
    this.weightTarget.value = Math.max(0, newValue)
    this.calculate()
  }

  incrementReps() {
    const current = parseInt(this.repsTarget.value) || 0
    if (current < 30) {
      this.repsTarget.value = current + 1
      this.calculate()
    }
  }

  decrementReps() {
    const current = parseInt(this.repsTarget.value) || 0
    if (current > 1) {
      this.repsTarget.value = current - 1
      this.calculate()
    }
  }
}
