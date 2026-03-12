import { Controller } from "@hotwired/stimulus"

// Keeps the add-set trigger hidden while an inline edit form is mounted.
export default class extends Controller {
  connect() {
    this.toggleExerciseCard(true)
  }

  disconnect() {
    this.toggleExerciseCard(false)
  }

  toggleExerciseCard(editingActive) {
    const exerciseCard = this.element.closest(".workout-exercise")
    if (!exerciseCard) return

    exerciseCard.classList.toggle("editing-set-inline", editingActive)

    const addSetButton = exerciseCard.querySelector("[data-add-set-toggle-target='button']")
    if (!addSetButton) return

    addSetButton.classList.toggle("d-none", editingActive)
    addSetButton.toggleAttribute("hidden", editingActive)
  }
}
