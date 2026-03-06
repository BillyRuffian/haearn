import { Controller } from "@hotwired/stimulus"

// Bidirectional swipe controller for touch-based actions on list items
// Swipe left to reveal right actions (e.g. delete)
// Swipe right to reveal left actions (e.g. duplicate)
//
// Usage:
//   <div data-controller="swipeable" data-swipeable-threshold-value="80">
//     <div data-swipeable-target="leftActions" class="swipe-actions swipe-actions-left">
//       <button data-action="click->swipeable#reset">Duplicate</button>
//     </div>
//     <div data-swipeable-target="content" class="swipeable-content">
//       Main content
//     </div>
//     <div data-swipeable-target="rightActions" class="swipe-actions swipe-actions-right">
//       <button data-action="click->swipeable#reset">Delete</button>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["content", "leftActions", "rightActions"]
  static values = {
    threshold: { type: Number, default: 80 },
    fullSwipeRatio: { type: Number, default: 0.55 },
    enabled: { type: Boolean, default: true }
  }

  connect() {
    this.startX = 0
    this.startY = 0
    this.currentX = 0
    this.isDragging = false
    this.openDirection = null // "left" or "right" or null

    if (!this.enabledValue) return

    this.boundTouchStart = this.handleTouchStart.bind(this)
    this.boundTouchMove = this.handleTouchMove.bind(this)
    this.boundTouchEnd = this.handleTouchEnd.bind(this)

    this.element.addEventListener("touchstart", this.boundTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.boundTouchMove, { passive: false })
    this.element.addEventListener("touchend", this.boundTouchEnd, { passive: true })
  }

  disconnect() {
    if (!this.enabledValue) return

    this.element.removeEventListener("touchstart", this.boundTouchStart)
    this.element.removeEventListener("touchmove", this.boundTouchMove)
    this.element.removeEventListener("touchend", this.boundTouchEnd)
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
    const deltaX = touch.clientX - this.startX
    const deltaY = Math.abs(touch.clientY - this.startY)

    // Only start dragging if horizontal movement dominates
    if (!this.isDragging && Math.abs(deltaX) > 10 && Math.abs(deltaX) > deltaY) {
      this.isDragging = true
      // If already open in a direction and user swipes opposite, reset first
      if (this.openDirection) {
        this.close()
        this.isDragging = false
        return
      }
    }

    if (!this.isDragging) return

    event.preventDefault()

    // Allow dragging up to full container width for full-swipe
    const containerWidth = this.element.offsetWidth
    const maxRight = this.hasLeftActionsTarget ? containerWidth : 0
    const maxLeft = this.hasRightActionsTarget ? containerWidth : 0

    const translateX = Math.max(-maxLeft, Math.min(maxRight, deltaX))
    this.currentX = translateX
    this.updatePosition(translateX)

    // Update action panel opacity and width for visual feedback
    if (translateX > 0 && this.hasLeftActionsTarget) {
      const progress = Math.min(translateX / this.thresholdValue, 1)
      this.leftActionsTarget.style.opacity = progress
      this.leftActionsTarget.style.width = `${Math.abs(translateX)}px`
    } else if (translateX < 0 && this.hasRightActionsTarget) {
      const progress = Math.min(Math.abs(translateX) / this.thresholdValue, 1)
      this.rightActionsTarget.style.opacity = progress
      this.rightActionsTarget.style.width = `${Math.abs(translateX)}px`
    }
  }

  handleTouchEnd() {
    if (!this.isDragging) return
    this.isDragging = false

    const containerWidth = this.element.offsetWidth
    const fullSwipeThreshold = containerWidth * this.fullSwipeRatioValue

    if (this.currentX > fullSwipeThreshold && this.hasLeftActionsTarget) {
      // Full swipe right — auto-trigger left action (duplicate)
      this.triggerAction(this.leftActionsTarget)
    } else if (this.currentX < -fullSwipeThreshold && this.hasRightActionsTarget) {
      // Full swipe left — auto-trigger right action (delete)
      this.triggerAction(this.rightActionsTarget)
    } else if (this.currentX > this.thresholdValue / 2 && this.hasLeftActionsTarget) {
      this.openLeft()
    } else if (this.currentX < -this.thresholdValue / 2 && this.hasRightActionsTarget) {
      this.openRight()
    } else {
      this.close()
    }
  }

  triggerAction(actionsTarget) {
    // Find the first submit button or link inside the action panel and click it
    const actionBtn = actionsTarget.querySelector("button[type='submit'], a, button")
    if (actionBtn) {
      this.close()
      actionBtn.click()
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

  openLeft() {
    this.openDirection = "left"
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(${this.thresholdValue}px)`
      this.contentTarget.style.transition = "transform 0.2s ease-out"
    }
    if (this.hasLeftActionsTarget) {
      this.leftActionsTarget.style.opacity = "1"
      this.leftActionsTarget.style.width = `${this.thresholdValue}px`
    }
    this.dispatch("opened", { detail: { direction: "left" } })
  }

  openRight() {
    this.openDirection = "right"
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(-${this.thresholdValue}px)`
      this.contentTarget.style.transition = "transform 0.2s ease-out"
    }
    if (this.hasRightActionsTarget) {
      this.rightActionsTarget.style.opacity = "1"
      this.rightActionsTarget.style.width = `${this.thresholdValue}px`
    }
    this.dispatch("opened", { detail: { direction: "right" } })
  }

  close() {
    this.openDirection = null
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateX(0)"
      this.contentTarget.style.transition = "transform 0.2s ease-out"

      // Remove inline transform after transition so it doesn't create
      // a containing block that traps dropdown menus
      const content = this.contentTarget
      const handler = () => {
        content.style.transform = ""
        content.style.transition = ""
        content.removeEventListener("transitionend", handler)
      }
      content.addEventListener("transitionend", handler)
    }
    if (this.hasLeftActionsTarget) {
      this.leftActionsTarget.style.opacity = "0"
      this.leftActionsTarget.style.width = "0"
    }
    if (this.hasRightActionsTarget) {
      this.rightActionsTarget.style.opacity = "0"
      this.rightActionsTarget.style.width = "0"
    }
    this.dispatch("closed")
  }

  reset() {
    this.close()
  }

  // Dispatch set-logged event to reset the rest timer (used by duplicate action)
  dispatchSetLogged() {
    const block = this.element.closest(".workout-block")
    const blockRestController = block?.querySelector("[data-controller~='block-rest']")
    const restSeconds = blockRestController ? parseInt(blockRestController.dataset.blockRestSecondsValue, 10) : null

    window.dispatchEvent(new CustomEvent("set-logged", {
      bubbles: true,
      detail: { restSeconds }
    }))
  }
}
