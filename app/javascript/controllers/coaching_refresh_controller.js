import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { active: Boolean, url: String }

  connect() {
    if (!this.activeValue) return
    this.interval = window.setInterval(() => this.refresh(), 5000)
  }

  disconnect() {
    window.clearInterval(this.interval)
  }

  refresh() {
    if (document.hidden || !navigator.onLine) return
    const frame = this.element.closest("turbo-frame")
    if (!frame || frame.hasAttribute("busy")) return
    if (frame.src === this.urlValue || frame.getAttribute("src") === this.urlValue) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }
}
