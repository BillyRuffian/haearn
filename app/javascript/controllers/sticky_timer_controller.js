import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sticky-timer"
// Shows a compact timer in navbar when the main workout timer scrolls out of view
export default class extends Controller {
  static values = { startedAt: String }
  static targets = ["main"]

  connect() {
    this.startTime = new Date(this.startedAtValue)
    this.navbarTimer = document.getElementById("navbar-workout-timer")

    this.updateDisplay()
    this.interval = setInterval(() => this.updateDisplay(), 60000) // Update every minute

    // Set up intersection observer to detect when main timer leaves viewport
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (this.navbarTimer) {
            // Show navbar timer when main timer is NOT visible
            if (entry.isIntersecting) {
              this.navbarTimer.style.display = "none"
            } else {
              this.navbarTimer.style.display = ""
            }
          }
        })
      },
      {
        threshold: 0,
        rootMargin: "-60px 0px 0px 0px" // Account for navbar height
      }
    )

    if (this.hasMainTarget) {
      this.observer.observe(this.mainTarget)
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
    if (this.observer) {
      this.observer.disconnect()
    }
    // Hide navbar timer when leaving the workout page
    if (this.navbarTimer) {
      this.navbarTimer.style.display = "none"
    }
  }

  updateDisplay() {
    const now = new Date()
    const diffMs = now - this.startTime
    const minutes = Math.floor(diffMs / 60000)

    // Update main display
    if (this.hasMainTarget) {
      const mainDisplay = this.mainTarget.querySelector("[data-timer-display]")
      if (mainDisplay) {
        mainDisplay.textContent = minutes
      }
    }

    // Update navbar display
    if (this.navbarTimer) {
      const navDisplay = this.navbarTimer.querySelector("[data-timer-display]")
      if (navDisplay) {
        navDisplay.textContent = minutes
      }
    }
  }
}
