import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Handles drag and drop reordering of workout blocks
export default class extends Controller {
  static values = {
    url: String,
    group: { type: String, default: "blocks" }
  }

  connect() {
    console.log("Sortable controller connected", this.element)

    this.sortable = Sortable.create(this.element, {
      animation: 200,
      handle: ".drag-handle",
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      group: this.groupValue,
      forceFallback: true, // Better mobile support
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  onEnd(event) {
    // Only save if position actually changed
    if (event.oldIndex === event.newIndex) return

    // Flash the dropped item to confirm the reorder
    const droppedEl = event.item
    droppedEl.classList.add("sortable-dropped")
    droppedEl.addEventListener("animationend", () => {
      droppedEl.classList.remove("sortable-dropped")
    }, { once: true })

    const blockIds = Array.from(this.element.children)
      .filter(el => el.dataset.blockId)
      .map(el => el.dataset.blockId)

    // Send PATCH request to update positions
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ block_ids: blockIds })
    }).then(response => {
      if (!response.ok) {
        console.error("Failed to save order")
      }
    })
  }
}
