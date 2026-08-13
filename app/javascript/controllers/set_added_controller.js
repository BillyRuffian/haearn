import { Controller } from "@hotwired/stimulus"

// Runs once after a successful set create/duplicate Turbo response has
// finished replacing the exercise card.
export default class extends Controller {
  static values = {
    blockId: String,
    restartTimer: { type: Boolean, default: true }
  }

  connect() {
    requestAnimationFrame(() => requestAnimationFrame(() => this.finish()))
  }

  finish() {
    if (this.restartTimerValue) {
      window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))
    }

    const block = document.getElementById(this.blockIdValue)
    if (block) this.scrollToVisibleTop(block)

    this.element.remove()
  }

  scrollToVisibleTop(block) {
    const blockTop = window.scrollY + block.getBoundingClientRect().top
    this.scrollInstantly(blockTop)

    requestAnimationFrame(() => this.clearVisibleNavbar(blockTop))
  }

  clearVisibleNavbar(blockTop) {
    const navbar = document.querySelector(".navbar.sticky-top")
    if (!navbar) return

    const bounds = navbar.getBoundingClientRect()
    if (bounds.top <= 0 && bounds.bottom > 0) {
      this.scrollInstantly(blockTop - bounds.bottom)
    }
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
}
