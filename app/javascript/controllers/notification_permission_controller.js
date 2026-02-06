import { Controller } from "@hotwired/stimulus"

// Manages notification permission requests and displays current status
export default class extends Controller {
  static targets = ["status", "button", "container"]

  connect() {
    this.updateStatus()
  }

  updateStatus() {
    if (!("Notification" in window)) {
      this.showNotSupported()
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
      const result = await Notification.requestPermission()
      this.updateStatus()

      // If granted, send a test notification
      if (result === "granted") {
        this.sendTestNotification()
      }
    }
  }

  sendTestNotification() {
    new Notification("Notifications Enabled! 🎉", {
      body: "You'll now receive alerts when your rest timer completes.",
      icon: "/icon.png",
      tag: "test-notification"
    })
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
