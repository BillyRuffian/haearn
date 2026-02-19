import { Controller } from "@hotwired/stimulus"

// Renders a simplified front/back body silhouette with muscle recovery overlays.
// Expects data like: { chest: { label, days_since, sets, volume }, ... }
export default class extends Controller {
  static targets = ["container", "tooltip"]
  static values = { data: Object }

  connect() {
    this.zoneListeners = []
    this.render()
  }

  disconnect() {
    this.detachZoneListeners()
  }

  render() {
    if (!this.hasContainerTarget) return

    const zones = this.zoneData()

    this.containerTarget.innerHTML = `
      <div class="body-map-shell">
        <div class="body-map-views">
          ${this.figureMarkup("Front", this.frontZones(), zones)}
          ${this.figureMarkup("Back", this.backZones(), zones)}
        </div>
        <div class="body-map-legend mt-3">
          <span><span class="legend-dot" style="background:#a33232"></span>Freshly trained</span>
          <span><span class="legend-dot" style="background:#b8860b"></span>Recovering</span>
          <span><span class="legend-dot" style="background:#3d7ea6"></span>Almost ready</span>
          <span><span class="legend-dot" style="background:#2d7a3e"></span>Ready</span>
        </div>
      </div>
    `

    this.attachZoneListeners()
  }

  zoneData() {
    const source = this.dataValue || {}
    const result = {}

    Object.entries(source).forEach(([muscle, value]) => {
      const daysSince = Number(value?.days_since)
      const knownDays = Number.isFinite(daysSince)
      result[muscle] = {
        label: value?.label || this.humanize(muscle),
        daysSince: knownDays ? daysSince : 999,
        sets: Number(value?.sets || 0),
        volume: Number(value?.volume || 0),
        color: this.recoveryColor(knownDays ? daysSince : 999)
      }
    })

    return result
  }

  figureMarkup(label, zoneDefs, zones) {
    return `
      <div class="body-map-figure">
        <div class="body-map-figure-label">${label}</div>
        <svg viewBox="0 0 100 135" class="body-map-svg" role="img" aria-label="${label} body recovery map">
          <circle cx="50" cy="10" r="7" class="body-base" />
          <rect x="40" y="18" width="20" height="17" rx="8" class="body-base" />
          <rect x="32" y="32" width="36" height="34" rx="10" class="body-base" />
          <rect x="36" y="66" width="28" height="16" rx="8" class="body-base" />
          <rect x="34" y="82" width="12" height="30" rx="6" class="body-base" />
          <rect x="54" y="82" width="12" height="30" rx="6" class="body-base" />
          <rect x="35" y="112" width="10" height="18" rx="5" class="body-base" />
          <rect x="55" y="112" width="10" height="18" rx="5" class="body-base" />
          <rect x="20" y="32" width="10" height="26" rx="5" class="body-base" />
          <rect x="70" y="32" width="10" height="26" rx="5" class="body-base" />
          <rect x="17" y="58" width="9" height="22" rx="4" class="body-base" />
          <rect x="74" y="58" width="9" height="22" rx="4" class="body-base" />

          ${zoneDefs.map((zone) => this.zoneMarkup(zone, zones)).join("")}
        </svg>
      </div>
    `
  }

  zoneMarkup(zone, zones) {
    const data = zones[zone.muscle] || {
      label: this.humanize(zone.muscle),
      daysSince: 999,
      sets: 0,
      volume: 0,
      color: "#4b4f54"
    }

    return `
      <rect x="${zone.x}" y="${zone.y}" width="${zone.w}" height="${zone.h}" rx="${zone.r || 5}"
            class="body-map-zone"
            style="--zone-color:${data.color}"
            data-muscle="${zone.muscle}"
            data-label="${data.label}"
            data-days-since="${data.daysSince}"
            data-sets="${data.sets}"
            data-volume="${data.volume}" />
    `
  }

  frontZones() {
    return [
      { muscle: "shoulders", x: 30, y: 20, w: 40, h: 11, r: 5 },
      { muscle: "chest", x: 34, y: 33, w: 32, h: 13, r: 5 },
      { muscle: "biceps", x: 20, y: 34, w: 10, h: 18, r: 5 },
      { muscle: "biceps", x: 70, y: 34, w: 10, h: 18, r: 5 },
      { muscle: "forearms", x: 17, y: 56, w: 9, h: 20, r: 4 },
      { muscle: "forearms", x: 74, y: 56, w: 9, h: 20, r: 4 },
      { muscle: "core", x: 39, y: 49, w: 22, h: 18, r: 5 },
      { muscle: "quadriceps", x: 34, y: 82, w: 12, h: 25, r: 5 },
      { muscle: "quadriceps", x: 54, y: 82, w: 12, h: 25, r: 5 },
      { muscle: "calves", x: 35, y: 111, w: 10, h: 18, r: 5 },
      { muscle: "calves", x: 55, y: 111, w: 10, h: 18, r: 5 }
    ]
  }

  backZones() {
    return [
      { muscle: "shoulders", x: 30, y: 20, w: 40, h: 11, r: 5 },
      { muscle: "back", x: 33, y: 32, w: 34, h: 23, r: 6 },
      { muscle: "triceps", x: 20, y: 34, w: 10, h: 18, r: 5 },
      { muscle: "triceps", x: 70, y: 34, w: 10, h: 18, r: 5 },
      { muscle: "forearms", x: 17, y: 56, w: 9, h: 20, r: 4 },
      { muscle: "forearms", x: 74, y: 56, w: 9, h: 20, r: 4 },
      { muscle: "glutes", x: 38, y: 63, w: 24, h: 12, r: 6 },
      { muscle: "hamstrings", x: 34, y: 82, w: 12, h: 25, r: 5 },
      { muscle: "hamstrings", x: 54, y: 82, w: 12, h: 25, r: 5 },
      { muscle: "calves", x: 35, y: 111, w: 10, h: 18, r: 5 },
      { muscle: "calves", x: 55, y: 111, w: 10, h: 18, r: 5 }
    ]
  }

  attachZoneListeners() {
    this.detachZoneListeners()

    this.containerTarget.querySelectorAll(".body-map-zone").forEach((zone) => {
      const onEnter = () => this.showTooltip(zone)
      const onLeave = () => this.hideTooltip()
      const onClick = (event) => {
        event.preventDefault()
        if (this.tooltipTarget.classList.contains("d-none")) {
          this.showTooltip(zone)
        } else {
          this.hideTooltip()
        }
      }

      zone.addEventListener("mouseenter", onEnter)
      zone.addEventListener("mouseleave", onLeave)
      zone.addEventListener("click", onClick)

      this.zoneListeners.push({ zone, onEnter, onLeave, onClick })
    })
  }

  detachZoneListeners() {
    this.zoneListeners.forEach(({ zone, onEnter, onLeave, onClick }) => {
      zone.removeEventListener("mouseenter", onEnter)
      zone.removeEventListener("mouseleave", onLeave)
      zone.removeEventListener("click", onClick)
    })
    this.zoneListeners = []
  }

  showTooltip(zone) {
    if (!this.hasTooltipTarget) return

    const label = zone.dataset.label
    const days = Number(zone.dataset.daysSince)
    const sets = Number(zone.dataset.sets || 0)
    const volume = Number(zone.dataset.volume || 0)

    const status = days >= 999 ? "No recent training" : (days === 0 ? "Trained today" : `Last trained ${days}d ago`)
    this.tooltipTarget.innerHTML = `<strong>${label}</strong><br>${status}<br>${sets} sets · ${this.formatNumber(volume)} volume`
    this.tooltipTarget.classList.remove("d-none")

    const rect = zone.getBoundingClientRect()
    const containerRect = this.containerTarget.getBoundingClientRect()

    this.tooltipTarget.style.left = `${rect.left - containerRect.left + rect.width / 2}px`
    this.tooltipTarget.style.top = `${rect.top - containerRect.top - 8}px`
  }

  hideTooltip() {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.classList.add("d-none")
  }

  recoveryColor(daysSince) {
    if (daysSince === 0) return "#a33232"
    if (daysSince === 1) return "#b8860b"
    if (daysSince <= 2) return "#3d7ea6"
    if (daysSince <= 6) return "#2d7a3e"
    return "#4b4f54"
  }

  humanize(value) {
    return String(value)
      .replaceAll("_", " ")
      .replace(/\b\w/g, (m) => m.toUpperCase())
  }

  formatNumber(num) {
    if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`
    if (num >= 1000) return `${(num / 1000).toFixed(1)}k`
    return `${num}`
  }
}
