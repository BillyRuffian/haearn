import { Controller } from "@hotwired/stimulus"

// One layout-level presence lease and badge coordinator per browser window.
export default class extends Controller {
  static values = { authenticated: Boolean }

  connect() {
    this.clientId = crypto.randomUUID()
    this.sequence = 0
    this.connected = true
    this.resumeHandler = () => this.resume()
    this.hideHandler = () => this.reportPresence(false)
    this.refreshHandler = () => this.refreshBadge()
    this.workerHandler = event => {
      if (event.data?.type === "NOTIFICATIONS_CHANGED") window.dispatchEvent(new Event("notifications:refresh"))
    }
    document.addEventListener("visibilitychange", this.resumeHandler)
    window.addEventListener("pageshow", this.resumeHandler)
    window.addEventListener("focus", this.resumeHandler)
    window.addEventListener("blur", this.hideHandler)
    window.addEventListener("pagehide", this.hideHandler)
    window.addEventListener("online", this.resumeHandler)
    window.addEventListener("notifications:refresh", this.refreshHandler)
    navigator.serviceWorker?.addEventListener("message", this.workerHandler)
    navigator.serviceWorker?.addEventListener("controllerchange", this.refreshHandler)
    this.heartbeat = setInterval(() => this.resume(), 15000)
    this.resume()
    navigator.serviceWorker?.ready.then(() => { if (this.connected) this.refreshBadge() })
  }

  disconnect() {
    this.reportPresence(false)
    this.connected = false
    clearInterval(this.heartbeat)
    document.removeEventListener("visibilitychange", this.resumeHandler)
    window.removeEventListener("pageshow", this.resumeHandler)
    window.removeEventListener("focus", this.resumeHandler)
    window.removeEventListener("blur", this.hideHandler)
    window.removeEventListener("pagehide", this.hideHandler)
    window.removeEventListener("online", this.resumeHandler)
    window.removeEventListener("notifications:refresh", this.refreshHandler)
    navigator.serviceWorker?.removeEventListener("message", this.workerHandler)
    navigator.serviceWorker?.removeEventListener("controllerchange", this.refreshHandler)
  }

  resume() {
    const visible = !document.hidden && document.hasFocus()
    this.reportPresence(visible)
    if (!document.hidden) this.refreshBadge()
  }

  reportPresence(visible) {
    if (!this.authenticatedValue || !navigator.onLine) return
    const body = new FormData()
    body.set("client_id", this.clientId)
    body.set("sequence", String(++this.sequence))
    body.set("visible", String(visible))
    body.set("authenticity_token", document.querySelector('meta[name="csrf-token"]')?.content || "")
    fetch("/notifications/presence", { method: "POST", body, credentials: "same-origin", keepalive: true })
      .catch(() => {}) // Lost/closed windows expire automatically on the server.
  }

  async refreshBadge() {
    if (!navigator.serviceWorker) return
    try {
      const registration = await navigator.serviceWorker.getRegistration()
      registration?.active?.postMessage({ type: "REFRESH_NOTIFICATION_BADGE" })
    } catch (_) { /* Badging must never interrupt logging. */ }
  }
}
