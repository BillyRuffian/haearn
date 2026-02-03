import { Controller } from "@hotwired/stimulus"

// Rest timer controller for between-set rest periods
// Connects to data-controller="rest-timer"
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 120 },  // Default 2 minutes
    autoStart: { type: Boolean, default: false }
  }
  static targets = ["display", "container", "progress", "collapsed"]

  connect() {
    this.remaining = this.durationValue
    this.isRunning = false
    this.interval = null

    // Load saved duration from localStorage if available
    const savedDuration = localStorage.getItem("haearn_rest_duration")
    if (savedDuration) {
      const parsed = parseInt(savedDuration, 10)
      // Only use saved value if it's reasonable (15s to 10min)
      if (parsed >= 15 && parsed <= 600) {
        this.remaining = parsed
        this.durationValue = parsed
      }
    }

    this.updateDisplay()

    if (this.autoStartValue) {
      this.start()
    }

    // Listen for set-logged events to auto-start timer
    this.setLoggedHandler = this.setLogged.bind(this)
    window.addEventListener("set-logged", this.setLoggedHandler)
  }

  disconnect() {
    this.stop()
    window.removeEventListener("set-logged", this.setLoggedHandler)
  }

  start() {
    if (this.isRunning) return

    this.isRunning = true
    this.showTimer()

    this.interval = setInterval(() => {
      this.remaining -= 1
      this.updateDisplay()

      if (this.remaining <= 0) {
        this.complete()
      }
    }, 1000)
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
    this.isRunning = false
  }

  skip() {
    this.stop()
    this.hideTimer()
    this.reset()
  }

  reset() {
    this.remaining = this.durationValue
    this.updateDisplay()
  }

  complete() {
    this.stop()
    this.playAlert()
    this.vibrate()

    // Flash the timer briefly, then hide
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("timer-complete")
      setTimeout(() => {
        this.hideTimer()
        this.containerTarget.classList.remove("timer-complete")
        this.reset()
      }, 2000)
    }
  }

  add15() {
    this.remaining += 15
    this.durationValue += 15
    this.saveDuration()
    this.updateDisplay()
  }

  subtract15() {
    if (this.remaining > 15) {
      this.remaining -= 15
      this.durationValue = Math.max(15, this.durationValue - 15)
      this.saveDuration()
      this.updateDisplay()
    }
  }

  saveDuration() {
    localStorage.setItem("haearn_rest_duration", this.durationValue.toString())
  }

  updateDisplay() {
    if (this.hasDisplayTarget) {
      const mins = Math.floor(this.remaining / 60)
      const secs = this.remaining % 60
      this.displayTarget.textContent = `${mins}:${secs.toString().padStart(2, "0")}`
    }

    if (this.hasProgressTarget) {
      const percent = (this.remaining / this.durationValue) * 100
      this.progressTarget.style.width = `${percent}%`
    }
  }

  showTimer() {
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.classList.add("d-none")
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("d-none")
      this.containerTarget.classList.add("timer-active")
    }
  }

  hideTimer() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("d-none")
      this.containerTarget.classList.remove("timer-active")
    }
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.classList.remove("d-none")
    }
  }

  playAlert() {
    // Create alert beeps using Web Audio API
    try {
      // Create or reuse audio context
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }

      // Resume audio context if it was suspended (browser autoplay policy)
      if (this.audioContext.state === "suspended") {
        this.audioContext.resume()
      }

      const playBeep = (startTime, frequency, duration) => {
        const oscillator = this.audioContext.createOscillator()
        const gainNode = this.audioContext.createGain()

        oscillator.connect(gainNode)
        gainNode.connect(this.audioContext.destination)

        oscillator.frequency.value = frequency
        oscillator.type = "sine"

        // Fade in/out to avoid clicks
        gainNode.gain.setValueAtTime(0, startTime)
        gainNode.gain.linearRampToValueAtTime(0.4, startTime + 0.01)
        gainNode.gain.linearRampToValueAtTime(0, startTime + duration)

        oscillator.start(startTime)
        oscillator.stop(startTime + duration)
      }

      const now = this.audioContext.currentTime
      // Three ascending beeps
      playBeep(now, 660, 0.15)        // E5
      playBeep(now + 0.2, 880, 0.15)  // A5
      playBeep(now + 0.4, 1100, 0.25) // C#6 (longer final beep)
    } catch (e) {
      console.log("Audio not available:", e)
    }
  }

  vibrate() {
    // Vibrate if supported (mobile devices)
    if ("vibrate" in navigator) {
      navigator.vibrate([200, 100, 200, 100, 200])
    }
  }

  // Called when a set is logged - auto-start the timer
  setLogged() {
    this.reset()
    this.start()
  }
}
