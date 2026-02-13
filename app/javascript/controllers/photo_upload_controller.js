import { Controller } from "@hotwired/stimulus"

// Preview a selected photo before upload
// Connects to data-controller="photo-upload"
export default class extends Controller {
  static targets = ["input", "preview", "image"]

  preview(event) {
    const file = event.target.files[0]
    if (!file) return

    if (!file.type.startsWith("image/")) return

    const reader = new FileReader()
    reader.onload = (e) => {
      if (this.hasImageTarget) {
        this.imageTarget.src = e.target.result
      }
      if (this.hasPreviewTarget) {
        this.previewTarget.classList.remove("d-none")
      }
    }
    reader.readAsDataURL(file)
  }
}
