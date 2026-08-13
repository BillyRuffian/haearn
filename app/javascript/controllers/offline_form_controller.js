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
    method: { type: String, default: "POST" },
    kind: { type: String, default: "form" },
    listId: String,
    setNumber: Number,
    unit: String,
    exerciseType: String
  }

  connect() {
    this.form = this.element.tagName === "FORM" ? this.element : this.element.querySelector("form")
    this.queued = false
    this.boundFetchError = this.handleFetchError.bind(this)
    this.form.addEventListener("turbo:fetch-request-error", this.boundFetchError)
    this.restorePendingSubmissions()
  }

  disconnect() {
    this.form?.removeEventListener("turbo:fetch-request-error", this.boundFetchError)
  }

  async submit(event) {
    this.submission = this.buildSubmission()
    this.queued = false

    if (navigator.onLine) return

    event.preventDefault()
    event.stopImmediatePropagation()
    if (this.form.dataset.turboConfirm && !window.confirm(this.form.dataset.turboConfirm)) return
    await this.queueSubmission()
  }

  async handleFetchError(event) {
    event.preventDefault()
    await this.queueSubmission()
  }

  buildSubmission() {
    const entries = Array.from(new FormData(this.form).entries())
    const requestId = entries.find(([name]) => name === "exercise_set[client_request_id]")?.[1] || this.generateRequestId()

    return {
      url: this.urlValue || this.form.action,
      method: this.methodValue || this.form.method?.toUpperCase() || "POST",
      entries,
      requestId,
      kind: this.kindValue,
      presentation: {
        listId: this.listIdValue,
        setNumber: this.setNumberValue,
        unit: this.unitValue,
        exerciseType: this.exerciseTypeValue
      },
      createdAt: Date.now(),
      attempts: 0
    }
  }

  async queueSubmission() {
    if (this.queued || !this.submission) return

    await this.queueForSync(this.submission)
    this.queued = true

    if (this.kindValue === "exercise_set") this.renderPendingSet(this.submission)
    if (this.kindValue === "finish_workout") this.renderPendingFinish()

    this.dispatch("queued", { detail: { item: this.submission } })
    this.prepareNextSubmission()
    await this.registerBackgroundSync()
  }

  renderPendingSet(item) {
    const presentation = item.presentation || {}
    const list = document.getElementById(presentation.listId || this.listIdValue)
    if (!list || document.querySelector(`[data-offline-request-id="${item.requestId}"]`)) return

    const values = Object.fromEntries(item.entries)
    const row = document.createElement("div")
    row.className = "row g-0 align-items-center py-1 set-row offline-pending-set"
    row.dataset.offlineRequestId = item.requestId

    const weight = values["exercise_set[weight_value]"] || "-"
    const exerciseType = presentation.exerciseType || this.exerciseTypeValue
    const metricName = exerciseType === "time" ? "duration_seconds" :
      exerciseType === "distance" ? "distance_meters" : "reps"
    const metricSuffix = exerciseType === "time" ? "s" : exerciseType === "distance" ? "m" : ""
    const metric = `${values[`exercise_set[${metricName}]`] || "-"}${metricSuffix}`
    const effort = values["exercise_set[rpe]"] ? `RPE ${values["exercise_set[rpe]"]}` :
      values["exercise_set[rir]"] ? `RIR ${values["exercise_set[rir]"]}` : "Pending"
    const warmup = values["exercise_set[is_warmup]"] === "1"

    row.append(
      this.cell(warmup ? "W" : String(presentation.setNumber || this.setNumberValue), "col-1 text-center"),
      this.cell(`${weight} ${presentation.unit || this.unitValue}`, "col-3 text-center"),
      this.cell(metric, "col-3 text-center"),
      this.cell(effort, "col-3 text-center small"),
      this.cell("Queued", "col-2 text-end offline-pending-label")
    )
    list.append(row)
  }

  cell(text, className) {
    const cell = document.createElement("div")
    cell.className = className
    cell.textContent = text
    return cell
  }

  renderPendingFinish() {
    const button = this.form.querySelector("button, input[type='submit']")
    if (!button) return
    button.disabled = true
    if (button.tagName === "INPUT") button.value = "Finish queued"
    else button.textContent = "Finish queued"
  }

  prepareNextSubmission() {
    if (this.kindValue !== "exercise_set") return

    const requestIdField = this.form.querySelector('[name="exercise_set[client_request_id]"]')
    if (requestIdField) requestIdField.value = this.generateRequestId()
    this.setNumberValue += 1
  }

  generateRequestId() {
    if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID()

    return `${Date.now()}-${Math.random().toString(16).slice(2)}-${Math.random().toString(16).slice(2)}`
  }

  async restorePendingSubmissions() {
    if (this.kindValue !== "exercise_set") return

    try {
      const pending = await this.pendingItems()
      const matching = pending
        .filter((item) => item.kind === "exercise_set" && item.url === (this.urlValue || this.form.action))
        .sort((a, b) => (a.createdAt || 0) - (b.createdAt || 0))

      matching.forEach((item) => this.renderPendingSet(item))
      if (matching.length > 0) this.setNumberValue = Math.max(
        this.setNumberValue,
        ...matching.map((item) => Number(item.presentation?.setNumber || 0) + 1)
      )
    } catch (error) {
      console.warn("[OfflineForm] Unable to restore pending sets", error)
    }
  }

  async pendingItems() {
    const db = await this.openDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["pending"], "readonly")
      const request = transaction.objectStore("pending").getAll()
      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result || [])
    })
  }

  async registerBackgroundSync() {
    try {
      const registration = await navigator.serviceWorker?.ready
      await registration?.sync?.register("sync-workouts")
    } catch (_error) {
      // Online and visibility events still replay the queue where SyncManager is unavailable.
    }
  }

  async queueForSync(item) {
    const db = await this.openDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["pending"], "readwrite")
      const store = transaction.objectStore("pending")
      const index = store.index("requestId")
      const existingRequest = index.get(item.requestId)

      existingRequest.onerror = () => reject(existingRequest.error)
      existingRequest.onsuccess = () => {
        if (existingRequest.result) {
          resolve(existingRequest.result.id)
          return
        }

        const request = store.add(item)
        request.onerror = () => reject(request.error)
        request.onsuccess = () => resolve(request.result)
      }
    })
  }

  async openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("haearn-offline", 2)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result)

      request.onupgradeneeded = (event) => {
        const db = event.target.result
        if (!db.objectStoreNames.contains("pending")) {
          const pending = db.createObjectStore("pending", { keyPath: "id", autoIncrement: true })
          pending.createIndex("requestId", "requestId", { unique: true })
        } else {
          const pending = event.target.transaction.objectStore("pending")
          if (!pending.indexNames.contains("requestId")) pending.createIndex("requestId", "requestId", { unique: true })
        }
        if (!db.objectStoreNames.contains("exercises")) {
          db.createObjectStore("exercises", { keyPath: "id" })
        }
      }
    })
  }
}
