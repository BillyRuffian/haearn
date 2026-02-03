import { Controller } from "@hotwired/stimulus"

// Prevents device from sleeping while on workout screen
// Uses the Screen Wake Lock API
export default class extends Controller {
  connect() {
    this.wakeLock = null
    this.requestWakeLock()

    // Re-acquire wake lock when page becomes visible again
    this.visibilityHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.visibilityHandler)
  }

  disconnect() {
    this.releaseWakeLock()
    document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  async requestWakeLock() {
    if (!("wakeLock" in navigator)) {
      console.log("Wake Lock API not supported")
      return
    }

    try {
      this.wakeLock = await navigator.wakeLock.request("screen")
      console.log("Wake lock acquired")

      this.wakeLock.addEventListener("release", () => {
        console.log("Wake lock released")
      })
    } catch (err) {
      console.log("Wake lock request failed:", err.message)
    }
  }

  releaseWakeLock() {
    if (this.wakeLock) {
      this.wakeLock.release()
      this.wakeLock = null
    }
  }

  handleVisibilityChange() {
    if (document.visibilityState === "visible") {
      this.requestWakeLock()
    }
  }
}
