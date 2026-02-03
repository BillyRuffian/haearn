import { Controller } from "@hotwired/stimulus"

// Swipeable controller for touch-based delete/actions
// Enables swipe-to-reveal actions on list items
//
// Usage:
//   <div data-controller="swipeable" data-swipeable-threshold-value="80">
//     <div data-swipeable-target="content">Main content</div>
//     <div data-swipeable-target="actions" class="swipe-actions">
//       <button data-action="click->swipeable#reset" class="btn-delete">Delete</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["content", "actions"]
  static values = {
    threshold: { type: Number, default: 80 },
    enabled: { type: Boolean, default: true }
  }

  connect() {
    this.startX = 0
    this.currentX = 0
    this.isDragging = false
    this.isOpen = false

    if (!this.enabledValue) return

    this.boundHandleTouchStart = this.handleTouchStart.bind(this)
    this.boundHandleTouchMove = this.handleTouchMove.bind(this)
    this.boundHandleTouchEnd = this.handleTouchEnd.bind(this)

    this.element.addEventListener("touchstart", this.boundHandleTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.boundHandleTouchMove, { passive: false })
    this.element.addEventListener("touchend", this.boundHandleTouchEnd, { passive: true })
  }

  disconnect() {
    if (!this.enabledValue) return

    this.element.removeEventListener("touchstart", this.boundHandleTouchStart)
    this.element.removeEventListener("touchmove", this.boundHandleTouchMove)
    this.element.removeEventListener("touchend", this.boundHandleTouchEnd)
  }

  handleTouchStart(event) {
    if (event.touches.length !== 1) return

    this.startX = event.touches[0].clientX
    this.startY = event.touches[0].clientY
    this.isDragging = false
  }

  handleTouchMove(event) {
    if (event.touches.length !== 1) return

    const touch = event.touches[0]
    const deltaX = this.startX - touch.clientX
    const deltaY = Math.abs(this.startY - touch.clientY)

    // Only start dragging if horizontal movement is greater
    if (!this.isDragging && Math.abs(deltaX) > 10 && Math.abs(deltaX) > deltaY) {
      this.isDragging = true
    }

    if (!this.isDragging) return

    // Prevent vertical scrolling while swiping
    event.preventDefault()

    // Calculate position
    let translateX = -deltaX

    // If already open, adjust starting position
    if (this.isOpen) {
      translateX = -this.thresholdValue - deltaX
    }

    // Limit movement
    translateX = Math.max(-this.thresholdValue - 20, Math.min(20, translateX))

    this.currentX = translateX
    this.updatePosition(translateX)
  }

  handleTouchEnd() {
    if (!this.isDragging) return

    this.isDragging = false

    // Determine if we should open or close
    const shouldOpen = this.currentX < -this.thresholdValue / 2

    if (shouldOpen) {
      this.open()
    } else {
      this.close()
    }
  }

  updatePosition(x) {
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(${x}px)`
      this.contentTarget.style.transition = "none"
    }
  }

  open() {
    this.isOpen = true
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(-${this.thresholdValue}px)`
      this.contentTarget.style.transition = "transform 0.2s ease-out"
    }
    this.dispatch("opened")
  }

  close() {
    this.isOpen = false
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateX(0)"
      this.contentTarget.style.transition = "transform 0.2s ease-out"
    }
    this.dispatch("closed")
  }

  reset() {
    this.close()
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }
}
