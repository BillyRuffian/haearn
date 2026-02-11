import { Controller } from "@hotwired/stimulus"

// Rest timer controller for between-set rest periods
// Uses timestamps for accuracy even when app is backgrounded
// Persists timer state across navigation
// Connects to data-controller="rest-timer"
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 120 },  // Default 2 minutes
    autoStart: { type: Boolean, default: false }
  }
  static targets = ["display", "container", "progress", "collapsed"]

  connect() {
    this.totalDuration = this.durationValue
    this.endTime = null
    this.isRunning = false
    this.interval = null

    // Load saved duration from localStorage if available
    const savedDuration = localStorage.getItem("haearn_rest_duration")
    if (savedDuration) {
      const parsed = parseInt(savedDuration, 10)
      // Only use saved value if it's reasonable (15s to 10min)
      if (parsed >= 15 && parsed <= 600) {
        this.totalDuration = parsed
        this.durationValue = parsed
      }
    }

    // Check if there's a running timer from before navigation
    this.restoreTimerState()

    this.updateDisplay()

    if (this.autoStartValue && !this.isRunning) {
      this.start()
    }

    // Listen for set-logged events to auto-start timer
    this.setLoggedHandler = this.setLogged.bind(this)
    window.addEventListener("set-logged", this.setLoggedHandler)

    // Re-sync timer when page becomes visible (for backgrounded PWA)
    this.visibilityHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.visibilityHandler)
  }

  disconnect() {
    // Don't call stop() - just clear the interval but keep state in localStorage
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
    window.removeEventListener("set-logged", this.setLoggedHandler)
    document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  restoreTimerState() {
    const savedEndTime = localStorage.getItem("haearn_timer_end")
    if (savedEndTime) {
      const endTime = parseInt(savedEndTime, 10)
      const now = Date.now()

      if (endTime > now) {
        // Timer is still running
        this.endTime = endTime
        this.isRunning = true
        this.showTimer()
        this.startInterval()
      } else {
        // Timer expired while away - clear it
        this.clearTimerState()
      }
    }
  }

  saveTimerState() {
    if (this.endTime) {
      localStorage.setItem("haearn_timer_end", this.endTime.toString())
    }
  }

  clearTimerState() {
    localStorage.removeItem("haearn_timer_end")
  }

  get remaining() {
    if (!this.endTime) return this.totalDuration
    const now = Date.now()
    const remaining = Math.ceil((this.endTime - now) / 1000)
    return Math.max(0, remaining)
  }

  startInterval() {
    if (this.interval) return

    // Use shorter interval for responsive UI, but rely on timestamps for accuracy
    this.interval = setInterval(() => {
      this.updateDisplay()

      if (this.remaining <= 0) {
        this.complete()
      }
    }, 100) // Update frequently for smooth countdown
  }

  start() {
    if (this.isRunning) return

    this.isRunning = true
    this.endTime = Date.now() + (this.totalDuration * 1000)
    this.saveTimerState()
    this.showTimer()
    this.startInterval()
    this.warmUpAudio()
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
    this.isRunning = false
    this.endTime = null
    this.clearTimerState()
  }

  skip() {
    this.stop()
    this.hideTimer()
  }

  complete() {
    this.stop()
    this.playAlert()
    this.vibrate()
    this.showNotification("Rest Complete!", "Time to lift! 💪")

    // Flash the timer briefly, then hide
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("timer-complete")
      setTimeout(() => {
        this.hideTimer()
        this.containerTarget.classList.remove("timer-complete")
      }, 2000)
    }
  }

  add15() {
    if (this.isRunning && this.endTime) {
      this.endTime += 15 * 1000
      this.saveTimerState()
    }
    this.totalDuration += 15
    this.durationValue = this.totalDuration
    this.saveDuration()
    this.updateDisplay()
  }

  subtract15() {
    if (this.isRunning && this.endTime) {
      const newRemaining = this.remaining - 15
      if (newRemaining > 0) {
        this.endTime -= 15 * 1000
        this.saveTimerState()
      }
    }
    if (this.totalDuration > 15) {
      this.totalDuration -= 15
      this.durationValue = this.totalDuration
      this.saveDuration()
    }
    this.updateDisplay()
  }

  saveDuration() {
    localStorage.setItem("haearn_rest_duration", this.totalDuration.toString())
  }

  updateDisplay() {
    const remaining = this.remaining

    if (this.hasDisplayTarget) {
      const mins = Math.floor(remaining / 60)
      const secs = remaining % 60
      this.displayTarget.textContent = `${mins}:${secs.toString().padStart(2, "0")}`
    }

    if (this.hasProgressTarget) {
      const percent = (remaining / this.totalDuration) * 100
      this.progressTarget.style.width = `${percent}%`
    }
  }

  handleVisibilityChange() {
    if (document.visibilityState === "visible" && this.isRunning) {
      // Force immediate update when app comes back to foreground
      this.updateDisplay()

      // Check if timer completed while backgrounded
      if (this.remaining <= 0) {
        this.complete()
      }
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

  // Initialize audio context during user gesture (start/setLogged) so it's
  // ready to play when the timer completes (which is not a user gesture)
  warmUpAudio() {
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }
      if (this.audioContext.state === "suspended") {
        this.audioContext.resume()
      }
    } catch (e) {
      console.log("Audio context init failed:", e)
    }
  }

  playAlert() {
    // Play alert beeps using Web Audio API
    try {
      // Ensure audio context exists (warmUpAudio should have created it)
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }

      // Last-resort resume attempt
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

  showNotification(title, body) {
    // Only show notification if page is not visible (user switched tabs/apps)
    if (document.visibilityState === "visible") {
      return
    }

    if ("Notification" in window && Notification.permission === "granted") {
      new Notification(title, {
        body: body,
        icon: "/icon.png",
        badge: "/icon.png",
        tag: "rest-timer", // Prevents duplicate notifications
        requireInteraction: false,
        silent: false
      })
    }
  }

  // Request notification permission - call this from settings or first timer start
  static async requestPermission() {
    if ("Notification" in window && Notification.permission === "default") {
      return await Notification.requestPermission()
    }
    return Notification.permission
  }

  // Called when a set is logged - auto-start the timer
  setLogged() {
    // Stop any existing timer and start fresh
    this.stop()
    this.warmUpAudio()
    this.start()
  }
}
