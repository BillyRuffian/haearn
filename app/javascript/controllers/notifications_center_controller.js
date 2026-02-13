import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["list", "badge", "empty", "loading"]
  static values = {
    feedUrl: String,
    markAllUrl: String,
    pollInterval: { type: Number, default: 30000 }
  }

  connect() {
    this.load()
    this.refreshHandler = this.load.bind(this)
    window.addEventListener("notifications:refresh", this.refreshHandler)
    this.startPolling()
  }

  disconnect() {
    window.removeEventListener("notifications:refresh", this.refreshHandler)
    this.stopPolling()
  }

  async load() {
    if (!this.hasFeedUrlValue) return
    this.showLoading(true)

    try {
      const response = await fetch(this.feedUrlValue, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      if (!response.ok) return

      const payload = await response.json()
      this.render(payload.notifications || [])
      this.updateBadge(payload.unread_count || 0)
    } finally {
      this.showLoading(false)
    }
  }

  async open(event) {
    event.preventDefault()
    const item = event.currentTarget
    const readUrl = item.dataset.readUrl
    const actionUrl = item.dataset.actionUrl

    if (readUrl) {
      await fetch(readUrl, {
        method: "PATCH",
        headers: this.requestHeaders()
      })
    }

    if (actionUrl) {
      Turbo.visit(actionUrl)
    } else {
      this.load()
    }
  }

  async markAllRead(event) {
    event.preventDefault()
    if (!this.hasMarkAllUrlValue) return

    await fetch(this.markAllUrlValue, {
      method: "PATCH",
      headers: this.requestHeaders()
    })
    this.load()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.load(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) clearInterval(this.pollTimer)
  }

  requestHeaders() {
    return {
      "X-CSRF-Token": this.csrfToken(),
      "X-Requested-With": "XMLHttpRequest",
      "Accept": "application/json"
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  }

  showLoading(show) {
    if (!this.hasLoadingTarget) return
    this.loadingTarget.classList.toggle("d-none", !show)
  }

  render(notifications) {
    if (!this.hasListTarget) return

    if (notifications.length === 0) {
      this.listTarget.innerHTML = ""
      if (this.hasEmptyTarget) this.emptyTarget.classList.remove("d-none")
      return
    }

    if (this.hasEmptyTarget) this.emptyTarget.classList.add("d-none")

    this.listTarget.innerHTML = notifications.map((notification) => {
      const when = this.timeAgo(notification.created_at)
      const severityClass = this.severityClass(notification.severity)
      const icon = this.iconFor(notification.kind)

      return `
        <button type="button"
                class="list-group-item list-group-item-action bg-transparent text-start notification-item ${severityClass}"
                data-action="click->notifications-center#open"
                data-read-url="${notification.read_url || ""}"
                data-action-url="${notification.action_url || ""}">
          <div class="d-flex justify-content-between align-items-start gap-2">
            <div class="min-w-0">
              <div class="fw-semibold"><i class="bi ${icon} me-1"></i>${this.escapeHtml(notification.title)}</div>
              <div class="small text-muted">${this.escapeHtml(notification.message)}</div>
            </div>
            <small class="text-muted flex-shrink-0">${when}</small>
          </div>
        </button>
      `
    }).join("")
  }

  updateBadge(count) {
    if (!this.hasBadgeTarget) return
    this.badgeTarget.textContent = String(count)
    this.badgeTarget.classList.toggle("d-none", count === 0)
  }

  severityClass(severity) {
    switch (severity) {
      case "success": return "notification-success"
      case "warning": return "notification-warning"
      case "danger": return "notification-danger"
      default: return "notification-info"
    }
  }

  iconFor(kind) {
    switch (kind) {
      case "readiness": return "bi-trophy-fill"
      case "plateau": return "bi-graph-down-arrow"
      case "streak_risk": return "bi-fire"
      case "volume_drop": return "bi-bar-chart-line"
      case "rest_timer": return "bi-stopwatch-fill"
      default: return "bi-bell-fill"
    }
  }

  timeAgo(isoString) {
    if (!isoString) return ""
    const seconds = Math.floor((Date.now() - new Date(isoString).getTime()) / 1000)
    if (seconds < 60) return "now"
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
    return `${Math.floor(seconds / 86400)}d`
  }

  escapeHtml(input) {
    return String(input)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
