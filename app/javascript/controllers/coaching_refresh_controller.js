import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["signal"]

  connect() {
    // A stream can connect after the analysis finishes, or reconnect after sleep.
    this.observer = new MutationObserver(() => {
      if (this.element.querySelector('turbo-cable-stream-source[connected]')) this.refresh()
    })
    const source = this.element.querySelector("turbo-cable-stream-source")
    if (source) this.observer.observe(source, { attributes: true, attributeFilter: ["connected"] })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  signalTargetConnected() {
    this.refresh()
  }

  resume() {
    if (!document.hidden) this.refresh()
  }

  frameLoaded() {
    if (!this.refreshPending) return
    this.refreshPending = false
    this.refresh()
  }

  refresh() {
    if (document.hidden || !navigator.onLine) return
    const frame = this.element.querySelector("turbo-frame")
    if (!frame || frame.querySelector('[data-coaching-live="false"]')) return
    if (frame.hasAttribute("busy")) {
      this.refreshPending = true
      return
    }
    if (frame.src === this.urlValue || frame.getAttribute("src") === this.urlValue) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }
}
