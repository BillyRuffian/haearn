import { Controller } from "@hotwired/stimulus"

// Fills in set form fields from previous session data
// Connects to data-controller="copy-last"
export default class extends Controller {
  static targets = ["weight", "reps", "duration", "distance", "warmup"]
  static values = {
    weight: String,
    reps: String,
    duration: String,
    distance: String,
    warmup: Boolean
  }

  fill() {
    if (this.hasWeightTarget && this.weightValue) {
      this.weightTarget.value = this.weightValue
      // Trigger input event for plate calculator updates
      this.weightTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    if (this.hasRepsTarget && this.repsValue) {
      this.repsTarget.value = this.repsValue
    }

    if (this.hasDurationTarget && this.durationValue) {
      this.durationTarget.value = this.durationValue
    }

    if (this.hasDistanceTarget && this.distanceValue) {
      this.distanceTarget.value = this.distanceValue
    }

    if (this.hasWarmupTarget) {
      this.warmupTarget.checked = this.warmupValue
    }
  }
}
