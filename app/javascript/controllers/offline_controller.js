import { Controller } from "@hotwired/stimulus"

// Offline detection and sync controller
// Monitors network status and manages offline workout queue
//
// Usage:
//   <div data-controller="offline" data-offline-show-class="d-block">
//     <div data-offline-target="indicator" class="d-none">
//       You're offline
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["indicator", "confidence", "dot", "status", "queueCount", "lastSynced", "syncButton"]
  static classes = ["show"]
  static values = {
    syncUrl: { type: String, default: "/api/sync" }
  }

  connect() {
    this.pendingCount = 0
    this.isSyncing = false
    this.syncError = null
    this.lastSyncedAt = this.readLastSyncedAt()

    this.onlineHandler = this.handleOnline.bind(this)
    this.offlineHandler = this.handleOffline.bind(this)
    this.serviceWorkerMessageHandler = this.handleServiceWorkerMessage.bind(this)
    this.queuedHandler = this.handleQueued.bind(this)

    this.updateStatus()
    this.refreshQueueCount()

    window.addEventListener("online", this.onlineHandler)
    window.addEventListener("offline", this.offlineHandler)

    // Listen for sync messages from service worker
    navigator.serviceWorker?.addEventListener("message", this.serviceWorkerMessageHandler)

    // Listen for newly queued offline form submissions
    this.element.addEventListener("offline-form:queued", this.queuedHandler)
  }

  disconnect() {
    window.removeEventListener("online", this.onlineHandler)
    window.removeEventListener("offline", this.offlineHandler)
    navigator.serviceWorker?.removeEventListener("message", this.serviceWorkerMessageHandler)
    this.element.removeEventListener("offline-form:queued", this.queuedHandler)
  }

  get isOnline() {
    return navigator.onLine
  }

  updateStatus() {
    if (this.hasIndicatorTarget) {
      if (this.isOnline) {
        this.indicatorTarget.classList.remove(this.showClass || "d-block")
        this.indicatorTarget.classList.add("d-none")
      } else {
        this.indicatorTarget.classList.add(this.showClass || "d-block")
        this.indicatorTarget.classList.remove("d-none")
      }
    }

    if (this.hasSyncButtonTarget) {
      this.syncButtonTarget.disabled = !this.isOnline || this.isSyncing || this.pendingCount === 0
    }

    this.renderConfidence()

    // Dispatch event for other controllers
    this.dispatch(this.isOnline ? "online" : "offline")
  }

  handleOnline() {
    console.log("[Offline] Back online")
    this.syncError = null
    this.updateStatus()
    this.syncPendingData()
  }

  handleOffline() {
    console.log("[Offline] Gone offline")
    this.updateStatus()
  }

  handleQueued() {
    this.syncError = null
    this.refreshQueueCount()
  }

  handleServiceWorkerMessage(event) {
    if (event.data?.type === "SYNC_WORKOUTS") {
      this.syncPendingData()
    }
  }

  // Sync any pending offline data
  async syncPendingData() {
    if (!this.isOnline || this.isSyncing) return

    try {
      this.isSyncing = true
      this.syncError = null
      this.updateStatus()

      const pendingData = await this.getPendingWorkouts()
      this.pendingCount = pendingData.length

      if (pendingData.length === 0) {
        console.log("[Offline] No pending data to sync")
        this.isSyncing = false
        this.updateStatus()
        return
      }

      console.log(`[Offline] Syncing ${pendingData.length} pending items`)

      for (const item of pendingData) {
        await this.syncItem(item)
      }

      this.lastSyncedAt = Date.now()
      this.persistLastSyncedAt(this.lastSyncedAt)
      this.dispatch("synced", { detail: { count: pendingData.length } })
    } catch (error) {
      console.error("[Offline] Sync failed:", error)
      this.syncError = error
      this.dispatch("syncFailed", { detail: { error } })
    } finally {
      this.isSyncing = false
      await this.refreshQueueCount()
      this.updateStatus()
    }
  }

  async syncItem(item) {
    const response = await fetch(item.url, {
      method: item.method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(item.data)
    })

    if (response.ok) {
      await this.removePendingItem(item.id)
    } else {
      throw new Error(`Sync failed: ${response.status}`)
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  // IndexedDB helpers
  async openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("haearn-offline", 1)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result)

      request.onupgradeneeded = (event) => {
        const db = event.target.result

        // Store for pending workout data
        if (!db.objectStoreNames.contains("pending")) {
          db.createObjectStore("pending", { keyPath: "id", autoIncrement: true })
        }

        // Store for cached exercises
        if (!db.objectStoreNames.contains("exercises")) {
          db.createObjectStore("exercises", { keyPath: "id" })
        }
      }
    })
  }

  async getPendingWorkouts() {
    const db = await this.openDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["pending"], "readonly")
      const store = transaction.objectStore("pending")
      const request = store.getAll()

      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result || [])
    })
  }

  async removePendingItem(id) {
    const db = await this.openDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["pending"], "readwrite")
      const store = transaction.objectStore("pending")
      const request = store.delete(id)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve()
    })
  }

  // Manual sync trigger
  sync(event) {
    event?.preventDefault()
    this.syncPendingData()
  }

  async refreshQueueCount() {
    try {
      const pending = await this.getPendingWorkouts()
      this.pendingCount = pending.length
    } catch (error) {
      console.warn("[Offline] Unable to read pending queue", error)
      this.pendingCount = 0
    }

    this.updateStatus()
  }

  renderConfidence() {
    if (!this.hasConfidenceTarget) return

    this.confidenceTarget.classList.remove("d-none")

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.statusText()
    }

    if (this.hasQueueCountTarget) {
      this.queueCountTarget.textContent = `${this.pendingCount} queued`
    }

    if (this.hasLastSyncedTarget) {
      this.lastSyncedTarget.textContent = this.lastSyncedText()
    }

    if (this.hasDotTarget) {
      this.dotTarget.className = `offline-confidence-dot ${this.dotStateClass()}`
    }

    if (this.hasSyncButtonTarget) {
      this.syncButtonTarget.textContent = this.syncError ? "Retry" : "Sync now"
    }
  }

  statusText() {
    if (!this.isOnline) return "Offline"
    if (this.isSyncing) return "Syncing..."
    if (this.syncError) return "Sync failed"
    if (this.pendingCount > 0) return "Online"
    return "Synced"
  }

  lastSyncedText() {
    if (!this.lastSyncedAt) return "Last synced: --"
    return `Last synced: ${new Date(this.lastSyncedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
  }

  dotStateClass() {
    if (!this.isOnline) return "offline-confidence-dot-offline"
    if (this.syncError) return "offline-confidence-dot-error"
    if (this.isSyncing) return "offline-confidence-dot-syncing"
    return "offline-confidence-dot-online"
  }

  persistLastSyncedAt(value) {
    try {
      window.localStorage.setItem("haearn:last-synced-at", String(value))
    } catch (_error) {
      // Ignore localStorage failures in private/sandboxed contexts
    }
  }

  readLastSyncedAt() {
    try {
      const value = window.localStorage.getItem("haearn:last-synced-at")
      return value ? Number(value) : null
    } catch (_error) {
      return null
    }
  }
}
