import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="body-map"
export default class extends Controller {
  static targets = ["container", "tooltip"]
  static values = {
    data: Object
  }

  // Muscle group positions for the body map grid layout
  // Using a simplified grid representation
  musclePositions = {
    // Front view
    chest: { label: "Chest", icon: "□", col: 1 },
    shoulders: { label: "Shoulders", icon: "◇", col: 2 },
    biceps: { label: "Biceps", icon: "◯", col: 1 },
    triceps: { label: "Triceps", icon: "◯", col: 2 },
    forearms: { label: "Forearms", icon: "│", col: 1 },
    core: { label: "Core", icon: "▢", col: 2 },
    quadriceps: { label: "Quads", icon: "▭", col: 1 },
    // Back view
    back: { label: "Back", icon: "▣", col: 2 },
    hamstrings: { label: "Hamstrings", icon: "▭", col: 1 },
    glutes: { label: "Glutes", icon: "◑", col: 2 },
    calves: { label: "Calves", icon: "▯", col: 1 },
    full_body: { label: "Full Body", icon: "⬡", col: 2 }
  }

  connect() {
    this.render()
  }

  render() {
    const data = this.dataValue
    const container = this.containerTarget

    let html = '<div class="body-map-grid">'

    // Group muscles into rows for nice layout
    const muscleOrder = [
      ["shoulders", "chest"],
      ["back", "core"],
      ["biceps", "triceps"],
      ["forearms", "full_body"],
      ["quadriceps", "glutes"],
      ["hamstrings", "calves"]
    ]

    muscleOrder.forEach(row => {
      html += '<div class="body-map-row">'
      row.forEach(muscleGroup => {
        const muscleData = data[muscleGroup]
        if (!muscleData) return

        const recovery = muscleData.recovery || 100
        const color = this.getRecoveryColor(recovery)
        const daysAgo = muscleData.days_ago
        const volume = muscleData.volume_7_days || 0

        let statusText = ""
        let statusClass = ""
        if (daysAgo === null) {
          statusText = "Never trained"
          statusClass = "text-muted"
        } else if (daysAgo === 0) {
          statusText = "Today"
          statusClass = "text-danger"
        } else if (daysAgo === 1) {
          statusText = "Yesterday"
          statusClass = "text-warning"
        } else if (daysAgo <= 3) {
          statusText = `${daysAgo}d ago`
          statusClass = "text-info"
        } else {
          statusText = `${daysAgo}d ago`
          statusClass = "text-success"
        }

        html += `
          <div class="body-map-muscle" 
               style="--recovery-color: ${color};"
               data-action="mouseenter->body-map#showTooltip mouseleave->body-map#hideTooltip"
               data-muscle="${muscleGroup}"
               data-days="${daysAgo}"
               data-volume="${volume}"
               data-recovery="${recovery}">
            <div class="muscle-indicator" style="background: ${color};"></div>
            <div class="muscle-info">
              <span class="muscle-name">${muscleData.label}</span>
              <span class="muscle-status ${statusClass}">${statusText}</span>
            </div>
          </div>
        `
      })
      html += '</div>'
    })

    html += '</div>'

    // Add legend
    html += `
      <div class="body-map-legend mt-3">
        <div class="d-flex justify-content-center gap-4 small">
          <span><span class="legend-dot" style="background: #dc3545;"></span> Just trained</span>
          <span><span class="legend-dot" style="background: #ffc107;"></span> Recovering</span>
          <span><span class="legend-dot" style="background: #17a2b8;"></span> Partial</span>
          <span><span class="legend-dot" style="background: #28a745;"></span> Rested</span>
        </div>
      </div>
    `

    container.innerHTML = html
  }

  getRecoveryColor(recovery) {
    // Color gradient from red (0% recovered) to green (100% recovered)
    if (recovery <= 20) return "#dc3545"  // Red - just trained
    if (recovery <= 40) return "#fd7e14"  // Orange - recovering
    if (recovery <= 60) return "#ffc107"  // Yellow - partial
    if (recovery <= 80) return "#17a2b8"  // Cyan - mostly recovered
    return "#28a745"                       // Green - fully rested
  }

  showTooltip(event) {
    const muscle = event.target.closest('.body-map-muscle')
    if (!muscle) return

    const muscleName = this.dataValue[muscle.dataset.muscle]?.label || muscle.dataset.muscle
    const days = muscle.dataset.days
    const volume = parseInt(muscle.dataset.volume) || 0
    const recovery = muscle.dataset.recovery

    let tooltipContent = `<strong>${muscleName}</strong><br>`
    if (days === "null" || days === null) {
      tooltipContent += `Never trained`
    } else {
      tooltipContent += `Last: ${days === "0" ? "Today" : days + " days ago"}<br>`
      tooltipContent += `Volume (7d): ${this.formatNumber(volume)}<br>`
      tooltipContent += `Recovery: ${recovery}%`
    }

    const tooltip = this.tooltipTarget
    tooltip.innerHTML = tooltipContent
    tooltip.classList.remove('d-none')

    const rect = muscle.getBoundingClientRect()
    const containerRect = this.containerTarget.getBoundingClientRect()

    tooltip.style.left = (rect.left - containerRect.left + rect.width / 2) + 'px'
    tooltip.style.top = (rect.top - containerRect.top - 10) + 'px'
  }

  hideTooltip() {
    this.tooltipTarget.classList.add('d-none')
  }

  formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M"
    if (num >= 1000) return (num / 1000).toFixed(1) + "k"
    return num.toLocaleString()
  }
}
