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
    this.syncSubscriptionState()
      .catch(() => {})
      .finally(() => this.refreshState())
  }

  async refreshState() {
    if (!("Notification" in window)) {
      this.showNotSupported()
      return
    }

    if (!this.hasPublicKeyValue) {
      this.showUnavailable()
      return
    }

    const permission = Notification.permission
    const subscribed = await this.isSubscribed()

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.getStatusText(permission, subscribed)
      this.statusTarget.className = `badge ${this.getStatusClass(permission, subscribed)}`
    }

    if (this.hasButtonTarget) {
      if (permission === "granted") {
        this.buttonTarget.disabled = false
        if (subscribed) {
          this.buttonTarget.textContent = "Disable Notifications"
          this.buttonTarget.classList.remove("btn-primary", "btn-success")
          this.buttonTarget.classList.add("btn-outline-secondary")
        } else {
          this.buttonTarget.textContent = "Enable Notifications"
          this.buttonTarget.classList.remove("btn-outline-secondary")
          this.buttonTarget.classList.add("btn-primary")
        }
      } else if (permission === "denied") {
        this.buttonTarget.textContent = "Blocked by Browser"
        this.buttonTarget.disabled = true
        this.buttonTarget.classList.remove("btn-primary", "btn-success", "btn-outline-secondary")
        this.buttonTarget.classList.add("btn-secondary")
      } else {
        this.buttonTarget.textContent = "Enable Notifications"
        this.buttonTarget.disabled = false
        this.buttonTarget.classList.remove("btn-success", "btn-secondary", "btn-outline-secondary")
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
    }

    if (Notification.permission === "granted") {
      const subscribed = await this.isSubscribed()
      if (subscribed) {
        await this.unsubscribe()
      } else {
        const success = await this.subscribe()
        if (success) this.sendTestNotification()
      }
    }

    await this.refreshState()
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
    if (!existing) await this.subscribe()
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

    const response = await fetch(this.subscribeUrlValue, {
      method: "POST",
      headers: this.requestHeaders(),
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })
    return response.ok
  }

  async unsubscribe() {
    if (!this.hasUnsubscribeUrlValue) return

    const registration = await this.serviceWorkerRegistration()
    if (!registration) return

    const subscription = await registration.pushManager.getSubscription()
    if (!subscription) return

    const response = await fetch(this.unsubscribeUrlValue, {
      method: "DELETE",
      headers: this.requestHeaders(),
      body: JSON.stringify({ endpoint: subscription.endpoint })
    })
    if (response.ok) {
      await subscription.unsubscribe()
    }
    return response.ok
  }

  async isSubscribed() {
    const registration = await this.serviceWorkerRegistration()
    if (!registration) return false

    const subscription = await registration.pushManager.getSubscription()
    return Boolean(subscription)
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

  getStatusText(permission, subscribed) {
    switch (permission) {
      case "granted": return subscribed ? "Enabled" : "Permission Granted"
      case "denied": return "Blocked"
      default: return "Not Set"
    }
  }

  getStatusClass(permission, subscribed) {
    switch (permission) {
      case "granted": return subscribed ? "bg-success" : "bg-warning"
      case "denied": return "bg-danger"
      default: return "bg-secondary"
    }
  }
}
