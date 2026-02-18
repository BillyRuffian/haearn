import { Controller } from "@hotwired/stimulus"

// Manages notification permission requests and displays current status
export default class extends Controller {
  static targets = ["status", "button", "container"]
  static values = {
    publicKey: String,
    subscribeUrl: String,
    unsubscribeUrl: String
  }

  connect() {
    this.updateStatus()
    this.syncSubscriptionState()
  }

  updateStatus() {
    if (!("Notification" in window)) {
      this.showNotSupported()
      return
    }

    if (!this.hasPublicKeyValue) {
      this.showUnavailable()
      return
    }

    const permission = Notification.permission

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.getStatusText(permission)
      this.statusTarget.className = `badge ${this.getStatusClass(permission)}`
    }

    if (this.hasButtonTarget) {
      if (permission === "granted") {
        this.buttonTarget.textContent = "Enabled"
        this.buttonTarget.disabled = true
        this.buttonTarget.classList.remove("btn-primary")
        this.buttonTarget.classList.add("btn-success")
      } else if (permission === "denied") {
        this.buttonTarget.textContent = "Blocked by Browser"
        this.buttonTarget.disabled = true
        this.buttonTarget.classList.remove("btn-primary")
        this.buttonTarget.classList.add("btn-secondary")
      } else {
        this.buttonTarget.textContent = "Enable Notifications"
        this.buttonTarget.disabled = false
        this.buttonTarget.classList.remove("btn-success", "btn-secondary")
        this.buttonTarget.classList.add("btn-primary")
      }
    }
  }

  async requestPermission() {
    if (!("Notification" in window)) {
      return
    }

    if (Notification.permission === "default") {
      await Notification.requestPermission()
      this.updateStatus()
    }

    if (Notification.permission === "granted") {
      await this.subscribe()
      this.sendTestNotification()
    }
  }

  sendTestNotification() {
    new Notification("Notifications Enabled! 🎉", {
      body: "You'll now receive alerts when your rest timer completes.",
      icon: "/icon.png",
      tag: "test-notification"
    })
  }

  async syncSubscriptionState() {
    if (!("serviceWorker" in navigator) || !this.hasPublicKeyValue) return

    if (Notification.permission !== "granted") return

    const registration = await this.serviceWorkerRegistration()
    if (!registration) return

    const existing = await registration.pushManager.getSubscription()
    if (!existing) {
      await this.subscribe()
    }
  }

  async subscribe() {
    if (!this.hasSubscribeUrlValue || !this.hasPublicKeyValue) return

    const registration = await this.serviceWorkerRegistration()
    if (!registration) return

    let subscription = await registration.pushManager.getSubscription()
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.publicKeyValue)
      })
    }

    await fetch(this.subscribeUrlValue, {
      method: "POST",
      headers: this.requestHeaders(),
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })
  }

  async unsubscribe() {
    if (!this.hasUnsubscribeUrlValue) return

    const registration = await this.serviceWorkerRegistration()
    if (!registration) return

    const subscription = await registration.pushManager.getSubscription()
    if (!subscription) return

    await fetch(this.unsubscribeUrlValue, {
      method: "DELETE",
      headers: this.requestHeaders(),
      body: JSON.stringify({ endpoint: subscription.endpoint })
    })
    await subscription.unsubscribe()
  }

  async serviceWorkerRegistration() {
    try {
      if (!("serviceWorker" in navigator)) return null

      const existing = await navigator.serviceWorker.getRegistration()
      if (existing) return existing

      return await navigator.serviceWorker.register("/service-worker")
    } catch (e) {
      console.log("Service worker registration failed:", e)
      return null
    }
  }

  requestHeaders() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": this.csrfToken(),
      "X-Requested-With": "XMLHttpRequest",
      "Accept": "application/json"
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)))
  }

  showNotSupported() {
    if (this.hasContainerTarget) {
      this.containerTarget.innerHTML = `
        <div class="text-muted">
          <i class="bi bi-exclamation-triangle me-1"></i>
          Notifications are not supported in this browser
        </div>
      `
    }
  }

  showUnavailable() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Unavailable"
      this.statusTarget.className = "badge bg-secondary"
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Not Configured"
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.remove("btn-primary", "btn-success")
      this.buttonTarget.classList.add("btn-secondary")
    }
  }

  getStatusText(permission) {
    switch (permission) {
      case "granted": return "Enabled"
      case "denied": return "Blocked"
      default: return "Not Set"
    }
  }

  getStatusClass(permission) {
    switch (permission) {
      case "granted": return "bg-success"
      case "denied": return "bg-danger"
      default: return "bg-secondary"
    }
  }
}
