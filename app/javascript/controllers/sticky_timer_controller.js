import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sticky-timer"
// Shows a compact timer in navbar when the main workout timer scrolls out of view
// On mobile (< 992px), always shows the navbar timer
export default class extends Controller {
  static values = { startedAt: String }
  static targets = ["main"]

  connect() {
    this.startTime = new Date(this.startedAtValue)
    this.navbarTimer = document.getElementById("navbar-workout-timer")
    this.mobileBreakpoint = 992 // Bootstrap lg breakpoint

    this.updateDisplay()
    this.interval = setInterval(() => this.updateDisplay(), 60000) // Update every minute

    // Set up intersection observer to detect when main timer leaves viewport
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          this.mainTimerVisible = entry.isIntersecting
          this.updateNavbarVisibility()
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

    // Listen for window resize to handle mobile/desktop transitions
    this.resizeHandler = () => this.updateNavbarVisibility()
    window.addEventListener("resize", this.resizeHandler)
    
    // Initial visibility check
    this.mainTimerVisible = true
    this.updateNavbarVisibility()

    // Scroll to bottom if returning to active workout (not first visit)
    const visitKey = "haearn_workout_visited"
    if (sessionStorage.getItem(visitKey) === "true") {
      // Returning to workout - scroll to bottom after a brief delay for rendering
      requestAnimationFrame(() => {
        window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
      })
    }
    sessionStorage.setItem(visitKey, "true")
  }

  updateNavbarVisibility() {
    if (!this.navbarTimer) return

    const isMobile = window.innerWidth < this.mobileBreakpoint
    
    if (isMobile) {
      // On mobile, always show navbar timer
      this.navbarTimer.style.display = ""
    } else {
      // On desktop, show only when main timer is scrolled out of view
      this.navbarTimer.style.display = this.mainTimerVisible ? "none" : ""
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
    }
    // Hide navbar timer when leaving the workout page
    if (this.navbarTimer) {
      this.navbarTimer.style.display = "none"
    }
    // Don't clear visited flag here - we want it to persist across navigations
    // It gets cleared when the workout is no longer active (page won't have this controller)
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
