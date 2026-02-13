import { Controller } from "@hotwired/stimulus"

// Photo comparison: updates images/overlays when selecting from dropdowns
// Connects to data-controller="photo-compare"
export default class extends Controller {
  static targets = [
    "leftSelect", "rightSelect",
    "leftImage", "rightImage",
    "leftDate", "leftWeight",
    "rightDate", "rightWeight"
  ]

  updateLeft() {
    this.updateSide("left")
  }

  updateRight() {
    this.updateSide("right")
  }

  updateSide(side) {
    const select = side === "left" ? this.leftSelectTarget : this.rightSelectTarget
    const option = select.options[select.selectedIndex]

    if (!option || !option.value) return

    const url = option.dataset.url
    const date = option.dataset.date
    const weight = option.dataset.weight

    const imageTarget = side === "left" ? this.leftImageTarget : this.rightImageTarget
    const dateTarget = side === "left" ? this.leftDateTarget : this.rightDateTarget
    const weightTarget = side === "left" ? this.leftWeightTarget : this.rightWeightTarget

    // Update image
    if (url) {
      if (imageTarget.tagName === "IMG") {
        imageTarget.src = url
      } else {
        // Replace placeholder div with img
        const img = document.createElement("img")
        img.src = url
        img.className = "img-fluid w-100"
        img.dataset[`photoCompareTarget`] = `${side}Image`
        imageTarget.replaceWith(img)
      }
    }

    // Update overlay
    if (dateTarget) {
      dateTarget.textContent = date || ""
      dateTarget.closest(".progress-photo-show-overlay")?.classList.remove("d-none")
    }
    if (weightTarget) {
      weightTarget.textContent = weight || ""
    }
  }
}
