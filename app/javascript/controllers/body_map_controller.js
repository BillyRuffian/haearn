import { Controller } from "@hotwired/stimulus"

// Renders front/back body silhouettes with clickable muscle-zone overlays.
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
        <svg viewBox="0 0 220 420" class="body-map-svg" role="img" aria-label="${label} body recovery map">
          ${this.baseFigureMarkup(view)}
          ${zoneDefs.map((zone) => this.zoneMarkup(zone, zones)).join("")}
        </svg>
      </div>
    `
  }

  baseFigureMarkup(view) {
    if (view === "front") {
      return `
        <circle cx="110" cy="34" r="20" class="body-base" />
        <path d="M96 58 C102 66,118 66,124 58 L122 76 C118 83,102 83,98 76 Z" class="body-base" />
        <path d="M84 82 C94 72,126 72,136 82 C146 94,145 130,138 156 C130 182,126 210,124 250 C123 290,129 330,132 378 L116 378 C112 334,109 299,110 252 C109 299,106 334,102 378 L88 378 C92 328,97 286,96 248 C94 208,90 182,82 156 C75 130,74 94,84 82 Z" class="body-base" />
        <path d="M83 86 C70 96,63 108,58 124 C52 143,50 166,54 188 C58 210,66 230,73 248 L86 241 C78 220,71 202,68 184 C65 165,66 146,71 130 C75 117,82 105,92 98 Z" class="body-base" />
        <path d="M137 86 C150 96,157 108,162 124 C168 143,170 166,166 188 C162 210,154 230,147 248 L134 241 C142 220,149 202,152 184 C155 165,154 146,149 130 C145 117,138 105,128 98 Z" class="body-base" />
        <path d="M100 252 C96 300,92 340,90 404 L104 404 C106 361,109 320,110 278 C111 320,114 361,116 404 L130 404 C128 340,124 300,120 252 Z" class="body-base" />
      `
    }

    return `
      <circle cx="110" cy="34" r="20" class="body-base" />
      <path d="M96 58 C102 66,118 66,124 58 L122 76 C118 83,102 83,98 76 Z" class="body-base" />
      <path d="M84 82 C94 72,126 72,136 82 C146 94,145 132,138 160 C130 188,126 214,124 250 C123 292,129 332,132 378 L116 378 C112 334,109 299,110 254 C109 299,106 334,102 378 L88 378 C92 332,97 292,96 250 C94 214,90 188,82 160 C75 132,74 94,84 82 Z" class="body-base" />
      <path d="M83 86 C70 96,63 108,58 124 C52 143,50 166,54 188 C58 210,66 230,73 248 L86 241 C78 220,71 202,68 184 C65 165,66 146,71 130 C75 117,82 105,92 98 Z" class="body-base" />
      <path d="M137 86 C150 96,157 108,162 124 C168 143,170 166,166 188 C162 210,154 230,147 248 L134 241 C142 220,149 202,152 184 C155 165,154 146,149 130 C145 117,138 105,128 98 Z" class="body-base" />
      <path d="M100 254 C96 302,92 342,90 404 L104 404 C106 363,109 322,110 282 C111 322,114 363,116 404 L130 404 C128 342,124 302,120 254 Z" class="body-base" />
      <path d="M87 86 C95 80,125 80,133 86" class="body-outline" />
      <path d="M95 114 C102 126,118 126,125 114" class="body-outline" />
      <path d="M94 146 C102 158,118 158,126 146" class="body-outline" />
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

    return `<path d="${zone.d}" class="body-map-zone" style="--zone-color:${data.color}" data-muscle="${zone.muscle}" data-label="${data.label}" data-days-since="${data.daysSince}" data-sets="${data.sets}" data-volume="${data.volume}" />`
  }

  frontZones() {
    return [
      { muscle: "shoulders", d: "M84 84 C93 74,102 72,110 77 C102 86,96 95,90 104 C84 100,79 93,84 84 Z" },
      { muscle: "shoulders", d: "M136 84 C127 74,118 72,110 77 C118 86,124 95,130 104 C136 100,141 93,136 84 Z" },
      { muscle: "chest", d: "M92 104 C100 95,120 95,128 104 C127 120,119 130,110 132 C101 130,93 120,92 104 Z" },
      { muscle: "core", d: "M98 133 C103 128,117 128,122 133 C123 151,120 173,110 183 C100 173,97 151,98 133 Z" },
      { muscle: "biceps", d: "M70 116 C74 104,84 101,91 108 C89 126,84 143,76 152 C69 145,66 130,70 116 Z" },
      { muscle: "biceps", d: "M150 116 C146 104,136 101,129 108 C131 126,136 143,144 152 C151 145,154 130,150 116 Z" },
      { muscle: "forearms", d: "M66 154 C72 147,80 147,85 154 C83 172,78 192,70 208 C63 194,61 173,66 154 Z" },
      { muscle: "forearms", d: "M154 154 C148 147,140 147,135 154 C137 172,142 192,150 208 C157 194,159 173,154 154 Z" },
      { muscle: "quadriceps", d: "M93 214 C100 209,106 210,110 218 C109 260,105 300,99 340 C91 331,86 303,85 260 C86 239,88 223,93 214 Z" },
      { muscle: "quadriceps", d: "M127 214 C120 209,114 210,110 218 C111 260,115 300,121 340 C129 331,134 303,135 260 C134 239,132 223,127 214 Z" },
      { muscle: "calves", d: "M95 343 C101 339,106 341,108 350 C107 368,105 386,102 402 C96 398,92 383,91 365 C91 355,92 348,95 343 Z" },
      { muscle: "calves", d: "M125 343 C119 339,114 341,112 350 C113 368,115 386,118 402 C124 398,128 383,129 365 C129 355,128 348,125 343 Z" }
    ]
  }

  backZones() {
    return [
      { muscle: "shoulders", d: "M84 84 C93 74,102 72,110 77 C102 86,96 95,90 104 C84 100,79 93,84 84 Z" },
      { muscle: "shoulders", d: "M136 84 C127 74,118 72,110 77 C118 86,124 95,130 104 C136 100,141 93,136 84 Z" },
      { muscle: "back", d: "M90 100 C97 91,123 91,130 100 C132 126,127 148,119 168 C115 176,105 176,101 168 C93 148,88 126,90 100 Z" },
      { muscle: "triceps", d: "M70 116 C74 104,84 101,91 108 C89 126,84 143,76 152 C69 145,66 130,70 116 Z" },
      { muscle: "triceps", d: "M150 116 C146 104,136 101,129 108 C131 126,136 143,144 152 C151 145,154 130,150 116 Z" },
      { muscle: "forearms", d: "M66 154 C72 147,80 147,85 154 C83 172,78 192,70 208 C63 194,61 173,66 154 Z" },
      { muscle: "forearms", d: "M154 154 C148 147,140 147,135 154 C137 172,142 192,150 208 C157 194,159 173,154 154 Z" },
      { muscle: "glutes", d: "M96 178 C102 172,118 172,124 178 C125 194,121 208,110 214 C99 208,95 194,96 178 Z" },
      { muscle: "hamstrings", d: "M93 214 C100 210,106 211,110 219 C108 252,103 290,98 332 C90 325,86 298,85 262 C86 240,88 223,93 214 Z" },
      { muscle: "hamstrings", d: "M127 214 C120 210,114 211,110 219 C112 252,117 290,122 332 C130 325,134 298,135 262 C134 240,132 223,127 214 Z" },
      { muscle: "calves", d: "M95 334 C101 330,106 332,108 341 C107 362,105 383,102 402 C96 399,92 385,91 366 C91 348,92 339,95 334 Z" },
      { muscle: "calves", d: "M125 334 C119 330,114 332,112 341 C113 362,115 383,118 402 C124 399,128 385,129 366 C129 348,128 339,125 334 Z" }
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
