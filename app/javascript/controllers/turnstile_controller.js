import { Controller } from "@hotwired/stimulus"

let scriptPromise

function loadTurnstile() {
  if (window.turnstile?.render) return Promise.resolve(window.turnstile)
  if (scriptPromise) return scriptPromise

  scriptPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
    script.async = true
    const fail = () => {
      clearTimeout(timeout)
      script.remove()
      scriptPromise = null
      reject(new Error("Verification could not load"))
    }
    const timeout = setTimeout(fail, 15000)
    script.onerror = fail
    script.onload = () => {
      clearTimeout(timeout)
      if (window.turnstile?.render) resolve(window.turnstile)
      else fail()
    }
    document.head.appendChild(script)
  })
  return scriptPromise
}

export default class extends Controller {
  static targets = ["widget", "status", "submit", "retry"]
  static values = { siteKey: String }

  connect() {
    this.active = true
    this.render()
  }

  disconnect() {
    this.teardown()
  }

  async render() {
    this.pending("Loading human verification…")
    try {
      const turnstile = await loadTurnstile()
      if (!this.active || this.widgetId != null) return
      this.pending("Please complete human verification.")
      this.widgetId = turnstile.render(this.widgetTarget, {
        sitekey: this.siteKeyValue,
        action: "signup",
        theme: "dark",
        size: "flexible",
        callback: () => {
          if (!this.active) return
          this.submitTarget.disabled = false
          this.statusTarget.textContent = "Human verification complete."
          this.retryTarget.hidden = true
        },
        "expired-callback": () => this.reset(),
        "timeout-callback": () => this.failed(),
        "error-callback": () => { this.failed(); return true }
      })
    } catch {
      this.failed()
    }
  }

  pending(message) {
    this.submitTarget.disabled = true
    this.statusTarget.textContent = message
    this.retryTarget.hidden = true
  }

  failed() {
    if (!this.active) return
    this.pending("Human verification could not finish. Please retry.")
    this.retryTarget.hidden = false
  }

  reset() {
    if (!this.active) return
    this.pending("Please complete human verification.")
    if (this.widgetId != null) window.turnstile.reset(this.widgetId)
  }

  retry() {
    if (this.widgetId != null) this.reset()
    else this.render()
  }

  teardown() {
    this.active = false
    if (this.widgetId != null) window.turnstile?.remove(this.widgetId)
    this.widgetId = null
    this.widgetTarget.replaceChildren()
    this.pending("Loading human verification…")
  }
}
