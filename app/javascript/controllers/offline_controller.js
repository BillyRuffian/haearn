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
  static targets = ["indicator", "syncButton"]
  static classes = ["show"]
  static values = {
    syncUrl: { type: String, default: "/api/sync" }
  }

  connect() {
    this.updateStatus()

    window.addEventListener("online", this.handleOnline.bind(this))
    window.addEventListener("offline", this.handleOffline.bind(this))

    // Listen for sync messages from service worker
    navigator.serviceWorker?.addEventListener("message", this.handleServiceWorkerMessage.bind(this))
  }

  disconnect() {
    window.removeEventListener("online", this.handleOnline.bind(this))
    window.removeEventListener("offline", this.handleOffline.bind(this))
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
      this.syncButtonTarget.disabled = !this.isOnline
    }

    // Dispatch event for other controllers
    this.dispatch(this.isOnline ? "online" : "offline")
  }

  handleOnline() {
    console.log("[Offline] Back online")
    this.updateStatus()
    this.syncPendingData()
  }

  handleOffline() {
    console.log("[Offline] Gone offline")
    this.updateStatus()
  }

  handleServiceWorkerMessage(event) {
    if (event.data?.type === "SYNC_WORKOUTS") {
      this.syncPendingData()
    }
  }

  // Sync any pending offline data
  async syncPendingData() {
    if (!this.isOnline) return

    try {
      const pendingData = await this.getPendingWorkouts()
      if (pendingData.length === 0) {
        console.log("[Offline] No pending data to sync")
        return
      }

      console.log(`[Offline] Syncing ${pendingData.length} pending items`)

      for (const item of pendingData) {
        await this.syncItem(item)
      }

      this.dispatch("synced", { detail: { count: pendingData.length } })
    } catch (error) {
      console.error("[Offline] Sync failed:", error)
      this.dispatch("syncFailed", { detail: { error } })
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
  sync() {
    this.syncPendingData()
  }
}
