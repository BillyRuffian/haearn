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
        <circle cx="110" cy="32" r="20" class="body-base" />
        <path d="M95 56 C101 65,119 65,125 56 L123 74 C119 80,101 80,97 74 Z" class="body-base" />
        <path d="M80 84 C92 72,128 72,140 84 C151 95,152 126,143 157 C136 181,130 206,128 234 C125 280,130 333,135 387 L120 387 C115 335,111 291,111 246 C109 291,105 335,100 387 L85 387 C90 333,95 281,92 234 C90 206,84 181,77 157 C68 126,69 95,80 84 Z" class="body-base" />
        <path d="M80 87 C65 99,57 112,52 129 C47 146,47 169,52 192 C57 214,67 235,76 254 L89 247 C79 225,70 205,66 185 C62 166,63 148,69 133 C73 120,82 107,94 99 Z" class="body-base" />
        <path d="M140 87 C155 99,163 112,168 129 C173 146,173 169,168 192 C163 214,153 235,144 254 L131 247 C141 225,150 205,154 185 C158 166,157 148,151 133 C147 120,138 107,126 99 Z" class="body-base" />
        <path d="M98 246 C93 294,88 338,86 406 L102 406 C104 360,108 315,109 268 C112 315,116 360,118 406 L134 406 C132 338,127 294,122 246 Z" class="body-base" />
      `
    }

    return `
      <circle cx="110" cy="32" r="20" class="body-base" />
      <path d="M95 56 C101 65,119 65,125 56 L123 74 C119 80,101 80,97 74 Z" class="body-base" />
      <path d="M80 84 C92 72,128 72,140 84 C151 95,152 127,143 160 C136 185,130 211,128 236 C125 282,130 334,135 387 L120 387 C115 335,111 291,111 248 C109 291,105 335,100 387 L85 387 C90 334,95 282,92 236 C90 211,84 185,77 160 C68 127,69 95,80 84 Z" class="body-base" />
      <path d="M80 87 C65 99,57 112,52 129 C47 146,47 169,52 192 C57 214,67 235,76 254 L89 247 C79 225,70 205,66 185 C62 166,63 148,69 133 C73 120,82 107,94 99 Z" class="body-base" />
      <path d="M140 87 C155 99,163 112,168 129 C173 146,173 169,168 192 C163 214,153 235,144 254 L131 247 C141 225,150 205,154 185 C158 166,157 148,151 133 C147 120,138 107,126 99 Z" class="body-base" />
      <path d="M98 248 C93 296,88 340,86 406 L102 406 C104 362,108 317,109 272 C112 317,116 362,118 406 L134 406 C132 340,127 296,122 248 Z" class="body-base" />
      <path d="M92 98 C100 90,120 90,128 98" class="body-outline" />
      <path d="M90 128 C98 141,122 141,130 128" class="body-outline" />
      <path d="M93 162 C100 172,120 172,127 162" class="body-outline" />
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
      { muscle: "shoulders", d: "M82 86 C93 74,103 71,111 78 C102 92,95 103,88 112 C80 106,76 95,82 86 Z" },
      { muscle: "shoulders", d: "M138 86 C127 74,117 71,109 78 C118 92,125 103,132 112 C140 106,144 95,138 86 Z" },
      { muscle: "chest", d: "M90 104 C99 92,121 92,130 104 C131 124,123 138,110 142 C97 138,89 124,90 104 Z" },
      { muscle: "core", d: "M97 143 C102 137,118 137,123 143 C124 168,120 191,110 206 C100 191,96 168,97 143 Z" },
      { muscle: "biceps", d: "M68 122 C72 108,83 102,92 110 C91 130,86 150,77 163 C69 154,65 138,68 122 Z" },
      { muscle: "biceps", d: "M152 122 C148 108,137 102,128 110 C129 130,134 150,143 163 C151 154,155 138,152 122 Z" },
      { muscle: "forearms", d: "M64 164 C71 154,80 154,87 163 C85 184,79 207,70 224 C62 209,59 186,64 164 Z" },
      { muscle: "forearms", d: "M156 164 C149 154,140 154,133 163 C135 184,141 207,150 224 C158 209,161 186,156 164 Z" },
      { muscle: "quadriceps", d: "M92 224 C100 216,107 216,111 226 C110 271,105 316,98 355 C89 344,84 312,83 269 C84 248,86 232,92 224 Z" },
      { muscle: "quadriceps", d: "M128 224 C120 216,113 216,109 226 C110 271,115 316,122 355 C131 344,136 312,137 269 C136 248,134 232,128 224 Z" },
      { muscle: "calves", d: "M94 356 C101 350,107 352,109 363 C108 380,105 396,101 408 C94 404,90 390,89 372 C89 365,90 360,94 356 Z" },
      { muscle: "calves", d: "M126 356 C119 350,113 352,111 363 C112 380,115 396,119 408 C126 404,130 390,131 372 C131 365,130 360,126 356 Z" }
    ]
  }

  backZones() {
    return [
      { muscle: "shoulders", d: "M82 86 C93 74,103 71,111 78 C102 92,95 103,88 112 C80 106,76 95,82 86 Z" },
      { muscle: "shoulders", d: "M138 86 C127 74,117 71,109 78 C118 92,125 103,132 112 C140 106,144 95,138 86 Z" },
      { muscle: "back", d: "M88 104 C96 92,124 92,132 104 C134 132,129 161,118 187 C114 195,106 195,102 187 C91 161,86 132,88 104 Z" },
      { muscle: "triceps", d: "M68 122 C72 108,83 102,92 110 C91 130,86 150,77 163 C69 154,65 138,68 122 Z" },
      { muscle: "triceps", d: "M152 122 C148 108,137 102,128 110 C129 130,134 150,143 163 C151 154,155 138,152 122 Z" },
      { muscle: "forearms", d: "M64 164 C71 154,80 154,87 163 C85 184,79 207,70 224 C62 209,59 186,64 164 Z" },
      { muscle: "forearms", d: "M156 164 C149 154,140 154,133 163 C135 184,141 207,150 224 C158 209,161 186,156 164 Z" },
      { muscle: "glutes", d: "M95 188 C101 180,119 180,125 188 C126 205,121 219,110 226 C99 219,94 205,95 188 Z" },
      { muscle: "hamstrings", d: "M92 228 C100 220,107 220,111 230 C109 270,104 308,97 345 C88 336,84 306,83 270 C84 252,86 236,92 228 Z" },
      { muscle: "hamstrings", d: "M128 228 C120 220,113 220,109 230 C111 270,116 308,123 345 C132 336,136 306,137 270 C136 252,134 236,128 228 Z" },
      { muscle: "calves", d: "M94 346 C101 340,107 342,109 353 C108 378,105 397,101 408 C94 404,90 390,89 370 C89 356,90 350,94 346 Z" },
      { muscle: "calves", d: "M126 346 C119 340,113 342,111 353 C112 378,115 397,119 408 C126 404,130 390,131 370 C131 356,130 350,126 346 Z" }
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
