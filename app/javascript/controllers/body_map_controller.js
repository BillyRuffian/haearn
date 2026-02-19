import { Controller } from "@hotwired/stimulus"

// Renders anatomical front/back body silhouettes with clickable muscle overlays.
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
          ${this.figureMarkup("Front", "front", this.frontZones(), zones)}
          ${this.figureMarkup("Back", "back", this.backZones(), zones)}
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

  figureMarkup(label, view, zoneDefs, zones) {
    return `
      <div class="body-map-figure">
        <div class="body-map-figure-label">${label}</div>
        <svg viewBox="0 0 260 470" class="body-map-svg" role="img" aria-label="${label} body recovery map">
          ${this.baseFigureMarkup(view)}
          ${zoneDefs.map((zone) => this.zoneMarkup(zone, zones)).join("")}
        </svg>
      </div>
    `
  }

  baseFigureMarkup(view) {
    const symbolId = view === "front" ? "anatomy-front" : "anatomy-back"
    return `<use href="#${symbolId}" class="body-base-symbol" />`
  }

  zoneMarkup(zone, zones) {
    const data = zones[zone.muscle] || {
      label: this.humanize(zone.muscle),
      daysSince: 999,
      sets: 0,
      volume: 0,
      color: "#4b4f54"
    }

    return `<path d="${zone.d}" class="body-map-zone" style="--zone-color:${data.color}" data-muscle="${zone.muscle}" data-label="${data.label}" data-days-since="${data.daysSince}" data-sets="${data.sets}" data-volume="${data.volume}" />`
  }

  frontZones() {
    return [
      { muscle: "shoulders", d: "M88 102 C96 89,114 82,129 91 C120 108,111 122,98 132 C87 126,83 113,88 102 Z" },
      { muscle: "shoulders", d: "M172 102 C164 89,146 82,131 91 C140 108,149 122,162 132 C173 126,177 113,172 102 Z" },
      { muscle: "chest", d: "M97 129 C107 114,153 114,163 129 C163 151,149 169,130 173 C111 169,97 151,97 129 Z" },
      { muscle: "core", d: "M108 175 C114 168,146 168,152 175 C155 210,147 241,130 262 C113 241,105 210,108 175 Z" },
      { muscle: "biceps", d: "M74 149 C79 131,92 122,103 129 C103 157,97 182,86 198 C76 186,70 169,74 149 Z" },
      { muscle: "biceps", d: "M186 149 C181 131,168 122,157 129 C157 157,163 182,174 198 C184 186,190 169,186 149 Z" },
      { muscle: "forearms", d: "M70 201 C78 190,90 190,98 201 C95 227,87 256,75 278 C65 259,61 231,70 201 Z" },
      { muscle: "forearms", d: "M190 201 C182 190,170 190,162 201 C165 227,173 256,185 278 C195 259,199 231,190 201 Z" },
      { muscle: "quadriceps", d: "M107 259 C116 250,126 250,131 262 C129 309,121 357,111 396 C99 383,93 343,93 304 C95 281,99 267,107 259 Z" },
      { muscle: "quadriceps", d: "M153 259 C144 250,134 250,129 262 C131 309,139 357,149 396 C161 383,167 343,167 304 C165 281,161 267,153 259 Z" },
      { muscle: "calves", d: "M108 398 C116 390,124 392,127 406 C126 423,122 437,116 446 C107 440,102 425,101 411 C101 404,103 400,108 398 Z" },
      { muscle: "calves", d: "M152 398 C144 390,136 392,133 406 C134 423,138 437,144 446 C153 440,158 425,159 411 C159 404,157 400,152 398 Z" }
    ]
  }

  backZones() {
    return [
      { muscle: "shoulders", d: "M88 102 C96 89,114 82,129 91 C120 108,111 122,98 132 C87 126,83 113,88 102 Z" },
      { muscle: "shoulders", d: "M172 102 C164 89,146 82,131 91 C140 108,149 122,162 132 C173 126,177 113,172 102 Z" },
      { muscle: "back", d: "M96 128 C106 112,154 112,164 128 C166 166,156 205,142 235 C137 244,123 244,118 235 C104 205,94 166,96 128 Z" },
      { muscle: "triceps", d: "M74 149 C79 131,92 122,103 129 C103 157,97 182,86 198 C76 186,70 169,74 149 Z" },
      { muscle: "triceps", d: "M186 149 C181 131,168 122,157 129 C157 157,163 182,174 198 C184 186,190 169,186 149 Z" },
      { muscle: "forearms", d: "M70 201 C78 190,90 190,98 201 C95 227,87 256,75 278 C65 259,61 231,70 201 Z" },
      { muscle: "forearms", d: "M190 201 C182 190,170 190,162 201 C165 227,173 256,185 278 C195 259,199 231,190 201 Z" },
      { muscle: "glutes", d: "M106 236 C114 226,146 226,154 236 C155 257,147 273,130 282 C113 273,105 257,106 236 Z" },
      { muscle: "hamstrings", d: "M106 284 C115 274,126 274,131 286 C129 325,122 362,112 390 C101 379,95 346,95 313 C97 297,100 289,106 284 Z" },
      { muscle: "hamstrings", d: "M154 284 C145 274,134 274,129 286 C131 325,138 362,148 390 C159 379,165 346,165 313 C163 297,160 289,154 284 Z" },
      { muscle: "calves", d: "M108 392 C116 384,124 386,127 399 C126 421,122 436,116 446 C108 441,103 426,102 408 C102 399,104 394,108 392 Z" },
      { muscle: "calves", d: "M152 392 C144 384,136 386,133 399 C134 421,138 436,144 446 C152 441,157 426,158 408 C158 399,156 394,152 392 Z" }
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
