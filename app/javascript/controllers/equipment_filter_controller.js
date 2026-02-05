import { Controller } from "@hotwired/stimulus"

// Filters equipment list in the add exercise modal
export default class extends Controller {
  static targets = ["input", "list", "item"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()

    this.itemTargets.forEach(item => {
      const name = item.dataset.name || ""
      if (query === "" || name.includes(query)) {
        item.style.display = ""
      } else {
        item.style.display = "none"
      }
    })
  }
}
