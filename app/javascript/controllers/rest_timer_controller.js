import { Controller } from "@hotwired/stimulus"

// Rest timer controller for between-set rest periods
// Uses timestamps for accuracy even when app is backgrounded
// Persists timer state across navigation
// Connects to data-controller="rest-timer"
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 120 },  // Current global rest duration
    defaultDuration: { type: Number, default: 120 }, // User-configured default
    autoStart: { type: Boolean, default: false }
  }
  static targets = ["display", "container", "progress", "collapsed"]

  connect() {
    this.totalDuration = this.defaultDurationValue
    this.endTime = null
    this.isRunning = false
    this.interval = null
    this.lastAlertAt = 0
    this.lastSetLoggedAt = 0

    const savedDuration = this.savedPreferredDuration()
    if (savedDuration) {
      this.totalDuration = savedDuration
      this.durationValue = savedDuration
    }

    this.initializePanelState()
    // Check if there's a running timer from before navigation
    this.restoreTimerState()
    this.updateDisplay()

    if (this.autoStartValue && !this.isRunning) {
      this.start()
    }

    // Listen for set-logged events to auto-start timer
    this.setLoggedHandler = this.setLogged.bind(this)
    window.addEventListener("set-logged", this.setLoggedHandler)

    // Turbo swaps can replace the workout-page panel targets while this
    // layout-mounted controller stays connected.
    this.turboSyncHandler = () => this.schedulePanelSync()
    document.addEventListener("turbo:load", this.turboSyncHandler)
    document.addEventListener("turbo:render", this.turboSyncHandler)

    // Re-sync timer when page becomes visible (for backgrounded PWA)
    this.visibilityHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.visibilityHandler)

    // iOS Safari/PWA can keep audio context suspended unless it is primed by gesture.
    this.pointerUnlockHandler = this.warmUpAudio.bind(this)
    window.addEventListener("pointerdown", this.pointerUnlockHandler, { once: true })
  }

  disconnect() {
    // Don't call stop() - just clear the interval but keep state in localStorage
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
    if (this.panelSyncFrame) {
      cancelAnimationFrame(this.panelSyncFrame)
      this.panelSyncFrame = null
    }
    if (this.panelSyncTimeout) {
      clearTimeout(this.panelSyncTimeout)
      this.panelSyncTimeout = null
    }
    if (this.panelSyncLateTimeout) {
      clearTimeout(this.panelSyncLateTimeout)
      this.panelSyncLateTimeout = null
    }
    window.removeEventListener("set-logged", this.setLoggedHandler)
    document.removeEventListener("turbo:load", this.turboSyncHandler)
    document.removeEventListener("turbo:render", this.turboSyncHandler)
    document.removeEventListener("visibilitychange", this.visibilityHandler)
    window.removeEventListener("pointerdown", this.pointerUnlockHandler)
  }

  collapsedTargetConnected() {
    this.schedulePanelSync()
  }

  containerTargetConnected() {
    this.schedulePanelSync()
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
        // Timer expired while away - complete it on reconnect so the user
        // still gets the alert after navigation/backgrounding.
        this.endTime = endTime
        this.isRunning = true
        this.complete()
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
    if (!this.isRunning || !this.endTime) return

    const now = Date.now()
    // Guard against duplicate/stray completes around rapid set logging.
    if (now - this.lastAlertAt < 1000) return

    const completionTimestamp = this.endTime || Date.now()
    this.stop()
    this.lastAlertAt = now
    this.renderCompletionState()
    this.playAlert()
    this.vibrate()
    this.showNotification("Rest Complete!", "Time to lift! 💪")
    this.persistInAppNotification(completionTimestamp, { suppressPush: true })

    // Flash the timer, then hide
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("timer-complete")
      setTimeout(() => {
        this.containerTarget.classList.add("timer-fade-out")
        setTimeout(() => {
          this.hideTimer()
          this.clearCompletionState()
          this.containerTarget.classList.remove("timer-complete", "timer-fade-out")
        }, 350)
      }, 5000)
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
    localStorage.setItem("haearn_rest_duration_default", this.defaultDurationValue.toString())
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

  renderCompletionState() {
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = "0:00"
    }

    if (this.hasProgressTarget) {
      this.progressTarget.style.width = "100%"
    }
  }

  clearCompletionState() {
    this.updateDisplay()
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
      this.setPanelVisible(this.collapsedTarget, false)
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("timer-active")
      this.setPanelVisible(this.containerTarget, true)
    }
  }

  hideTimer() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("timer-active")
      this.setPanelVisible(this.containerTarget, false)
    }
    if (this.hasCollapsedTarget) {
      this.setPanelVisible(this.collapsedTarget, true)
    }
  }

  initializePanelState() {
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.classList.remove("is-hidden")
      this.collapsedTarget.setAttribute("aria-hidden", "false")
      this.collapsedTarget.hidden = false
    }

    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("is-hidden")
      this.containerTarget.setAttribute("aria-hidden", "true")
      this.containerTarget.hidden = true
    }
  }

  setPanelVisible(panel, visible) {
    if (!panel) return

    if (visible) {
      requestAnimationFrame(() => {
        panel.classList.remove("is-hidden")
        panel.setAttribute("aria-hidden", "false")
        panel.hidden = false
      })
      return
    }

    panel.classList.add("is-hidden")
    panel.setAttribute("aria-hidden", "true")
    panel.hidden = true
  }

  syncPanelState() {
    if (!this.hasCollapsedTarget || !this.hasContainerTarget) return

    if (this.isRunning) {
      this.showTimer()
    } else {
      this.hideTimer()
    }
  }

  schedulePanelSync() {
    if (this.panelSyncFrame) {
      cancelAnimationFrame(this.panelSyncFrame)
    }
    if (this.panelSyncTimeout) {
      clearTimeout(this.panelSyncTimeout)
    }
    if (this.panelSyncLateTimeout) {
      clearTimeout(this.panelSyncLateTimeout)
    }

    this.panelSyncFrame = requestAnimationFrame(() => this.syncPanelState())
    this.panelSyncTimeout = setTimeout(() => this.syncPanelState(), 0)
    this.panelSyncLateTimeout = setTimeout(() => this.syncPanelState(), 60)
  }

  savedPreferredDuration() {
    const savedDuration = parseInt(localStorage.getItem("haearn_rest_duration"), 10)
    const savedDefault = parseInt(localStorage.getItem("haearn_rest_duration_default"), 10)

    if (!Number.isFinite(savedDuration) || savedDuration < 15 || savedDuration > 600) {
      return null
    }

    if (Number.isFinite(savedDefault)) {
      return savedDefault === this.defaultDurationValue ? savedDuration : null
    }

    // Old installs stored only the duration. Only trust it if it already matches
    // the current server-side default so stale client overrides do not win.
    return savedDuration === this.defaultDurationValue ? savedDuration : null
  }

  // Initialize audio context during user gesture (start/setLogged) so it's
  // ready to play when the timer completes (which is not a user gesture)
  warmUpAudio() {
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }
      if (this.audioContext.state === "suspended") {
        this.audioContext.resume().catch(() => {})
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
        this.audioContext.resume().catch(() => {})
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
    const backgroundAlertEnabled = document.body?.dataset?.restTimerBackgroundAlertEnabled !== "false"
    if (!backgroundAlertEnabled) {
      return
    }

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

  async persistInAppNotification(completedAtMs, { suppressPush = false } = {}) {
    try {
      const response = await fetch("/notifications/rest_timer_expired", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
          "X-Requested-With": "XMLHttpRequest",
          "Accept": "application/json"
        },
        body: JSON.stringify({
          completed_at_ms: completedAtMs,
          suppress_push: suppressPush
        })
      })

      if (response.ok) {
        window.dispatchEvent(new CustomEvent("notifications:refresh"))
      }
    } catch (e) {
      console.log("Failed to persist rest timer notification:", e)
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  }

  // Request notification permission - call this from settings or first timer start
  static async requestPermission() {
    if ("Notification" in window && Notification.permission === "default") {
      return await Notification.requestPermission()
    }
    return Notification.permission
  }

  // Stimulus callback when durationValue changes (e.g. via data attribute)
  durationValueChanged() {
    // Only update totalDuration if we're not currently running
    // (avoid resetting mid-countdown)
    if (!this.isRunning) {
      this.totalDuration = this.durationValue
      this.updateDisplay()
    }
  }

  // Called when a set is logged - auto-start the timer from the user's timer default
  setLogged(event) {
    this.lastSetLoggedAt = Date.now()
    this.totalDuration = this.savedPreferredDuration() || this.defaultDurationValue

    // Stop any existing timer and start fresh
    this.stop()
    this.warmUpAudio()
    this.start()
  }
}
