import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["signal", "review"]

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
    this.reviewObserver?.disconnect()
  }

  signalTargetConnected() {
    this.refresh()
  }

  resume() {
    if (!document.hidden) {
      this.refresh()
      this.acknowledgeVisibleReview()
    }
  }

  frameLoaded() {
    this.acknowledgeVisibleReview()
    if (!this.refreshPending) return
    this.refreshPending = false
    this.refresh()
  }

  reviewTargetConnected(element) {
    this.reviewObserver ||= new IntersectionObserver(() => this.acknowledgeVisibleReview())
    this.reviewObserver.observe(element)
  }

  reviewTargetDisconnected(element) {
    this.reviewObserver?.unobserve(element)
  }

  async acknowledgeVisibleReview() {
    if (document.hidden || !document.hasFocus() || !navigator.onLine || !this.hasReviewTarget) return
    const review = this.reviewTarget
    const rect = review.getBoundingClientRect()
    if (rect.bottom <= 0 || rect.top >= window.innerHeight) return
    const url = review.dataset.reviewReadUrl
    this.readReviews ||= new Set()
    if (!url || this.readReviews.has(url)) return
    this.readReviews.add(url)
    try {
      const response = await fetch(url, { method: "POST", headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        "Accept": "application/json"
      } })
      if (!response.ok) throw new Error("Review acknowledgement failed")
      window.dispatchEvent(new Event("notifications:refresh"))
    } catch (_) {
      this.readReviews.delete(url)
    }
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
