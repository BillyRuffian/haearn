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
    this.lastCountdownCueSecond = null
    this.audioContext = null
    this.audioUnlocked = false

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

    // iOS Safari/PWA can keep audio contexts suspended unless they are unlocked
    // from a real gesture and resumed again after page/app transitions.
    this.audioUnlockHandler = this.warmUpAudio.bind(this)
    this.pageShowHandler = this.handlePageShow.bind(this)
    document.addEventListener("touchstart", this.audioUnlockHandler, { capture: true, passive: true })
    document.addEventListener("pointerdown", this.audioUnlockHandler, { capture: true, passive: true })
    document.addEventListener("mousedown", this.audioUnlockHandler, { capture: true, passive: true })
    document.addEventListener("click", this.audioUnlockHandler, { capture: true, passive: true })
    document.addEventListener("keydown", this.audioUnlockHandler, { capture: true })
    window.addEventListener("pageshow", this.pageShowHandler)
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
    document.removeEventListener("touchstart", this.audioUnlockHandler, { capture: true })
    document.removeEventListener("pointerdown", this.audioUnlockHandler, { capture: true })
    document.removeEventListener("mousedown", this.audioUnlockHandler, { capture: true })
    document.removeEventListener("click", this.audioUnlockHandler, { capture: true })
    document.removeEventListener("keydown", this.audioUnlockHandler, { capture: true })
    window.removeEventListener("pageshow", this.pageShowHandler)
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
      const remaining = this.remaining
      this.updateDisplayFor(remaining)
      this.playCountdownCueIfNeeded(remaining)

      if (remaining <= 0) {
        this.complete()
      }
    }, 100) // Update frequently for smooth countdown
  }

  start() {
    if (this.isRunning) return

    this.resetCountdownCueState()
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
    this.resetCountdownCueState()
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
    this.updateDisplayFor(this.remaining)
  }

  updateDisplayFor(remaining) {
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
    if (document.visibilityState === "visible") {
      this.resumeAudioContext()
    }

    if (document.visibilityState === "visible" && this.isRunning) {
      // Force immediate update when app comes back to foreground
      const remaining = this.remaining
      this.updateDisplayFor(remaining)
      this.playCountdownCueIfNeeded(remaining)

      // Check if timer completed while backgrounded
      if (remaining <= 0) {
        this.complete()
      }
    }
  }

  handlePageShow() {
    this.resumeAudioContext()
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

  ensureAudioContext() {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    if (!AudioContextClass) {
      return null
    }

    try {
      if (!this.audioContext || this.audioContext.state === "closed") {
        this.audioContext = new AudioContextClass()
      }
      return this.audioContext
    } catch (error) {
      console.log("Audio context init failed:", error)
      return null
    }
  }

  resumeAudioContext() {
    const context = this.ensureAudioContext()
    if (!context) {
      return Promise.resolve(null)
    }

    if (context.state === "running") {
      this.audioUnlocked = true
      return Promise.resolve(context)
    }

    return context.resume()
      .then(() => {
        if (context.state === "running") {
          this.audioUnlocked = true
        }
        return context
      })
      .catch((error) => {
        console.log("Audio context resume failed:", error)
        return null
      })
  }

  // Prime Web Audio from a real user gesture so later countdown/completion cues
  // can still sound after timers finish asynchronously on iPhone Safari/PWA.
  warmUpAudio() {
    return this.resumeAudioContext().then((context) => {
      if (!context || context.state !== "running") {
        return null
      }

      try {
        const buffer = context.createBuffer(1, 1, context.sampleRate)
        const source = context.createBufferSource()
        const gainNode = context.createGain()

        source.buffer = buffer
        gainNode.gain.value = 0.00001

        source.connect(gainNode)
        gainNode.connect(context.destination)
        source.start(context.currentTime)
        source.stop(context.currentTime + 0.001)
        this.audioUnlocked = true
      } catch (error) {
        console.log("Audio warm-up pulse failed:", error)
      }

      return context
    })
  }

  playAlert() {
    this.withReadyAudioContext((context) => {
      const now = context.currentTime

      this.playShapedTone(context, {
        startTime: now,
        frequency: 146.83,
        duration: 0.28,
        gain: 0.42,
        overtoneFrequency: 220.0,
        overtoneGain: 0.06,
        lowpassFrequency: 620
      })
      this.playShapedTone(context, {
        startTime: now + 0.31,
        frequency: 164.81,
        duration: 0.28,
        gain: 0.44,
        overtoneFrequency: 246.94,
        overtoneGain: 0.065,
        lowpassFrequency: 660
      })
      this.playShapedTone(context, {
        startTime: now + 0.64,
        frequency: 123.47,
        duration: 0.62,
        gain: 0.52,
        overtoneFrequency: 185.0,
        overtoneGain: 0.08,
        lowpassFrequency: 540
      })
    }, "Audio not available:")
  }

  withReadyAudioContext(callback, logPrefix = "Audio not available:") {
    this.resumeAudioContext()
      .then((context) => {
        if (!context || context.state !== "running") {
          return
        }

        callback(context)
      })
      .catch((error) => {
        console.log(logPrefix, error)
      })
  }

  playShapedTone(context, {
    startTime,
    frequency,
    duration,
    gain = 0.28,
    overtoneFrequency = null,
    overtoneGain = 0.08,
    lowpassFrequency = 1100
  }) {
    try {
      const filterNode = context.createBiquadFilter()
      const gainNode = context.createGain()
      const mainOscillator = context.createOscillator()

      filterNode.type = "lowpass"
      filterNode.frequency.setValueAtTime(lowpassFrequency, startTime)
      gainNode.gain.setValueAtTime(0.00001, startTime)
      gainNode.gain.linearRampToValueAtTime(gain, startTime + 0.015)
      gainNode.gain.exponentialRampToValueAtTime(0.0001, startTime + duration)

      mainOscillator.type = "triangle"
      mainOscillator.frequency.setValueAtTime(frequency * 1.04, startTime)
      mainOscillator.frequency.exponentialRampToValueAtTime(frequency, startTime + 0.06)

      mainOscillator.connect(filterNode)
      filterNode.connect(gainNode)
      gainNode.connect(context.destination)

      const oscillators = [mainOscillator]

      if (overtoneFrequency) {
        const overtoneOscillator = context.createOscillator()
        const overtoneMix = context.createGain()

        overtoneOscillator.type = "sine"
        overtoneOscillator.frequency.setValueAtTime(overtoneFrequency * 1.02, startTime)
        overtoneOscillator.frequency.exponentialRampToValueAtTime(overtoneFrequency, startTime + 0.05)
        overtoneMix.gain.setValueAtTime(overtoneGain, startTime)

        overtoneOscillator.connect(overtoneMix)
        overtoneMix.connect(filterNode)
        oscillators.push(overtoneOscillator)
      }

      oscillators.forEach((oscillator) => {
        oscillator.start(startTime)
        oscillator.stop(startTime + duration)
      })
    } catch (error) {
      console.log("Tone shaping failed:", error)
    }
  }

  playCountdownCueIfNeeded(remaining) {
    if (remaining > 4 || remaining <= 0) {
      this.lastCountdownCueSecond = null
      return
    }

    if (remaining === this.lastCountdownCueSecond) {
      return
    }

    this.lastCountdownCueSecond = remaining
    this.playCountdownPip()
  }

  playCountdownPip() {
    this.withReadyAudioContext((context) => {
      this.playShapedTone(context, {
        startTime: context.currentTime,
        frequency: 130.81,
        duration: 0.2,
        gain: 0.28,
        overtoneFrequency: 196.0,
        overtoneGain: 0.045,
        lowpassFrequency: 520
      })
    }, "Countdown audio not available:")
  }

  resetCountdownCueState() {
    this.lastCountdownCueSecond = null
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
