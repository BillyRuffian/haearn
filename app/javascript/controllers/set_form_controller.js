import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="set-form"
export default class extends Controller {
  static targets = ["weight", "reps", "submit"]

  connect() {
    this.boundHandleOfflineQueued = this.handleOfflineQueued.bind(this)
    this.element.addEventListener("offline-form:queued", this.boundHandleOfflineQueued)
  }

  disconnect() {
    this.element.removeEventListener("offline-form:queued", this.boundHandleOfflineQueued)
  }

  handleOfflineQueued() {
    window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))

    const block = this.element.closest(".workout-block")
    if (!block) return

    const blockTop = window.scrollY + block.getBoundingClientRect().top
    this.scrollInstantly(blockTop)

    requestAnimationFrame(() => {
      const navbar = document.querySelector(".navbar.sticky-top")
      if (!navbar) return

      const bounds = navbar.getBoundingClientRect()
      if (bounds.top <= 0 && bounds.bottom > 0) {
        this.scrollInstantly(blockTop - bounds.bottom)
      }
    })
  }

  scrollInstantly(top) {
    const root = document.documentElement
    const previousBehavior = root.style.getPropertyValue("scroll-behavior")
    const previousPriority = root.style.getPropertyPriority("scroll-behavior")
    root.style.setProperty("scroll-behavior", "auto", "important")
    window.scrollTo({ top: Math.max(0, top) })

    if (previousBehavior) {
      root.style.setProperty("scroll-behavior", previousBehavior, previousPriority)
    } else {
      root.style.removeProperty("scroll-behavior")
    }
  }

  submitted() {
    // No-op: fields are prepopulated by the server via Turbo Stream replacement
  }
}
