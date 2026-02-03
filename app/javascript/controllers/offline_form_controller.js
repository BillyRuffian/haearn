import { Controller } from "@hotwired/stimulus"

// Offline workout queue controller
// Stores workout data in IndexedDB when offline
//
// Usage on a form:
//   <form data-controller="offline-form"
//         data-offline-form-url-value="/workouts/1/exercises/1/sets"
//         data-action="submit->offline-form#submit">
//
export default class extends Controller {
  static values = {
    url: String,
    method: { type: String, default: "POST" }
  }

  connect() {
    this.form = this.element.tagName === "FORM" ? this.element : this.element.querySelector("form")
  }

  async submit(event) {
    // If online, let normal form submission happen
    if (navigator.onLine) return

    // Prevent normal submission
    event.preventDefault()

    // Collect form data
    const formData = new FormData(this.form)
    const data = Object.fromEntries(formData.entries())

    // Queue for later sync
    await this.queueForSync({
      url: this.urlValue || this.form.action,
      method: this.methodValue || this.form.method?.toUpperCase() || "POST",
      data: data,
      timestamp: Date.now()
    })

    // Show feedback
    this.dispatch("queued", { detail: { data } })

    // Optionally reset form
    this.form.reset()
  }

  async queueForSync(item) {
    const db = await this.openDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["pending"], "readwrite")
      const store = transaction.objectStore("pending")
      const request = store.add(item)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => {
        console.log("[OfflineForm] Queued for sync:", item)
        resolve(request.result)
      }
    })
  }

  async openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("haearn-offline", 1)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result)

      request.onupgradeneeded = (event) => {
        const db = event.target.result
        if (!db.objectStoreNames.contains("pending")) {
          db.createObjectStore("pending", { keyPath: "id", autoIncrement: true })
        }
        if (!db.objectStoreNames.contains("exercises")) {
          db.createObjectStore("exercises", { keyPath: "id" })
        }
      }
    })
  }
}
