import { Controller } from "@hotwired/stimulus"

// Plate calculator - shows optimal plate combinations for barbell exercises
// Assumes a standard Olympic bar (defaults to user preference)
export default class extends Controller {
  static values = {
    weight: { type: Number, default: 0 },
    barWeight: { type: Number, default: 20 },
    unit: { type: String, default: "kg" }
  }

  static targets = ["display", "breakdown"]

  // Standard Olympic plates in kg with their colors
  // We'll show plates needed for ONE side (symmetric loading)
  static plates = {
    kg: [
      { weight: 25, color: "#dc2626", name: "Red" },      // Red
      { weight: 20, color: "#2563eb", name: "Blue" },     // Blue
      { weight: 15, color: "#eab308", name: "Yellow" },   // Yellow
      { weight: 10, color: "#16a34a", name: "Green" },    // Green
      { weight: 5, color: "#f8fafc", name: "White" },     // White
      { weight: 2.5, color: "#dc2626", name: "Red" },     // Red (smaller)
      { weight: 1.25, color: "#f8fafc", name: "White" }   // White (smaller)
    ],
    lbs: [
      { weight: 45, color: "#2563eb", name: "Blue" },     // Blue
      { weight: 35, color: "#eab308", name: "Yellow" },   // Yellow
      { weight: 25, color: "#16a34a", name: "Green" },    // Green
      { weight: 10, color: "#f8fafc", name: "White" },    // White
      { weight: 5, color: "#dc2626", name: "Red" },       // Red
      { weight: 2.5, color: "#16a34a", name: "Green" }    // Green (smaller)
    ]
  }

  connect() {
    this.calculate()
  }

  // Called when the weight input changes (via action)
  updateWeight(event) {
    const value = parseFloat(event.target.value) || 0
    this.weightValue = value
  }

  weightValueChanged() {
    this.calculate()
  }

  barWeightValueChanged() {
    this.calculate()
  }

  calculate() {
    const totalWeight = this.weightValue
    const barWeight = this.barWeightValue
    const unit = this.unitValue

    // Can't load less than bar weight
    if (totalWeight <= barWeight || totalWeight <= 0) {
      this.renderEmpty()
      return
    }

    // Weight to load per side
    const perSide = (totalWeight - barWeight) / 2
    const plates = this.calculatePlates(perSide, unit)

    this.render(plates, perSide, unit)
  }

  calculatePlates(targetWeight, unit) {
    const availablePlates = this.constructor.plates[unit] || this.constructor.plates.kg
    const result = []
    let remaining = targetWeight

    for (const plate of availablePlates) {
      while (remaining >= plate.weight) {
        result.push({ ...plate })
        remaining = Math.round((remaining - plate.weight) * 100) / 100 // Avoid floating point issues
      }
    }

    // Check if we can make the exact weight
    if (remaining > 0.01) {
      // Can't make exact weight with available plates
      return { plates: result, remainder: remaining, exact: false }
    }

    return { plates: result, remainder: 0, exact: true }
  }

  renderEmpty() {
    if (this.hasDisplayTarget) {
      this.displayTarget.innerHTML = ""
      this.displayTarget.classList.add("d-none")
    }
    if (this.hasBreakdownTarget) {
      this.breakdownTarget.innerHTML = ""
    }
  }

  render(result, perSide, unit) {
    if (!this.hasDisplayTarget) return

    this.displayTarget.classList.remove("d-none")

    // Build the visual representation
    const { plates, remainder, exact } = result

    if (plates.length === 0) {
      this.displayTarget.innerHTML = `
        <div class="plate-calc-empty text-muted small">
          <i class="bi bi-info-circle me-1"></i>
          Just the bar
        </div>
      `
      return
    }

    // Create the bar visualization
    let html = `
      <div class="plate-visualization d-flex align-items-center gap-1">
        <div class="bar-end" title="Bar collar"></div>
    `

    // Add plates (closest to bar first = heaviest first in our array)
    plates.forEach((plate, index) => {
      const size = this.getPlateSize(plate.weight, unit)
      html += `
        <div class="plate" 
             style="background: ${plate.color}; height: ${size}px; width: ${this.getPlateWidth(plate.weight, unit)}px;"
             title="${plate.weight}${unit}"
             data-weight="${plate.weight}">
          <span class="plate-label">${plate.weight}</span>
        </div>
      `
    })

    html += `
        <div class="bar-sleeve" title="Bar sleeve"></div>
      </div>
    `

    // Add text breakdown
    const plateCounts = this.countPlates(plates)
    const breakdownText = plateCounts.map(p => `${p.count}×${p.weight}${unit}`).join(" + ")

    html += `
      <div class="plate-breakdown small text-muted mt-1">
        <span class="me-2">Per side: ${perSide}${unit}</span>
        <span>${breakdownText}</span>
        ${!exact ? `<span class="text-warning ms-2"><i class="bi bi-exclamation-triangle"></i> +${remainder.toFixed(2)}${unit} needed</span>` : ""}
      </div>
    `

    this.displayTarget.innerHTML = html
  }

  getPlateSize(weight, unit) {
    // Return height in pixels based on plate weight
    // Larger plates are taller
    if (unit === "lbs") {
      if (weight >= 45) return 48
      if (weight >= 35) return 42
      if (weight >= 25) return 36
      if (weight >= 10) return 28
      return 22
    } else {
      // kg
      if (weight >= 25) return 48
      if (weight >= 20) return 44
      if (weight >= 15) return 38
      if (weight >= 10) return 32
      if (weight >= 5) return 26
      return 20
    }
  }

  getPlateWidth(weight, unit) {
    // Thicker plates for heavier weights
    if (unit === "lbs") {
      if (weight >= 45) return 12
      if (weight >= 25) return 10
      return 6
    } else {
      if (weight >= 20) return 12
      if (weight >= 10) return 10
      if (weight >= 5) return 8
      return 5
    }
  }

  countPlates(plates) {
    const counts = {}
    plates.forEach(p => {
      counts[p.weight] = (counts[p.weight] || 0) + 1
    })
    return Object.entries(counts)
      .map(([weight, count]) => ({ weight: parseFloat(weight), count }))
      .sort((a, b) => b.weight - a.weight)
  }
}
