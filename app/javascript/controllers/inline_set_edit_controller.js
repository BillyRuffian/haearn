import { Controller } from "@hotwired/stimulus"

// Keeps the add-set trigger hidden while an inline edit form is mounted.
export default class extends Controller {
  connect() {
    this.toggleExerciseCard(true)
    this.syncGlobalFormState()
  }

  disconnect() {
    this.toggleExerciseCard(false)
    this.syncGlobalFormState()
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

  syncGlobalFormState() {
    requestAnimationFrame(() => {
      const hasActiveSetForm = document.querySelector(
        ".workout-show-page [data-add-set-toggle-target='form']:not(.d-none), .workout-show-page form.edit-set-form"
      ) !== null

      document.body.classList.toggle("add-set-form-open", hasActiveSetForm)
    })
  }
}
