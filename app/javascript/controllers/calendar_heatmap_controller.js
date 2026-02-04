import { Controller } from "@hotwired/stimulus"

// GitHub-style calendar heatmap for workout consistency
// Shows last 52 weeks of workout activity
export default class extends Controller {
  static values = {
    data: Object // { "2026-02-04": 2, "2026-02-03": 1, ... } - date: workout count
  }

  static targets = ["container", "tooltip"]

  connect() {
    this.render()
    this.setupScrollFade()
  }

  setupScrollFade() {
    // Find the fade element (sibling of our container's parent)
    const card = this.element.closest('.heatmap-card')
    this.fadeElement = card?.querySelector('.heatmap-scroll-fade')
    
    if (this.fadeElement) {
      // Check scroll position on scroll
      this.element.addEventListener('scroll', this.updateFade.bind(this))
      // Initial check
      this.updateFade()
    }
  }

  updateFade() {
    if (!this.fadeElement) return
    
    const { scrollLeft, scrollWidth, clientWidth } = this.element
    const isAtEnd = scrollLeft + clientWidth >= scrollWidth - 5 // 5px threshold
    
    this.fadeElement.style.opacity = isAtEnd ? '0' : '1'
  }

  render() {
    const container = this.containerTarget
    container.innerHTML = ""
    
    // Generate last 52 weeks (364 days) of dates
    const today = new Date()
    const startDate = new Date(today)
    startDate.setDate(startDate.getDate() - 364)
    
    // Adjust to start on Sunday
    const dayOfWeek = startDate.getDay()
    startDate.setDate(startDate.getDate() - dayOfWeek)
    
    // Create wrapper
    const wrapper = document.createElement("div")
    wrapper.className = "heatmap-wrapper"
    
    // Day labels (Sun, Mon, etc.)
    const dayLabels = document.createElement("div")
    dayLabels.className = "heatmap-days"
    const days = ["", "Mon", "", "Wed", "", "Fri", ""]
    days.forEach(day => {
      const label = document.createElement("span")
      label.textContent = day
      dayLabels.appendChild(label)
    })
    
    // Main grid area (months + weeks)
    const gridArea = document.createElement("div")
    gridArea.className = "heatmap-grid-area"
    
    // Month labels row
    const monthLabels = document.createElement("div")
    monthLabels.className = "heatmap-months"
    
    // Weeks container
    const weeksContainer = document.createElement("div")
    weeksContainer.className = "heatmap-weeks"
    
    let currentDate = new Date(startDate)
    let lastMonth = -1
    const monthPositions = [] // Track where each month starts
    
    // Generate 53 weeks
    for (let week = 0; week < 53; week++) {
      const weekColumn = document.createElement("div")
      weekColumn.className = "heatmap-week"
      
      for (let day = 0; day < 7; day++) {
        const cell = document.createElement("div")
        const dateStr = this.formatDate(currentDate)
        const count = this.dataValue[dateStr] || 0
        
        // Track month changes (use first day of each week for label positioning)
        if (day === 0 && currentDate.getMonth() !== lastMonth && currentDate <= today) {
          lastMonth = currentDate.getMonth()
          monthPositions.push({
            month: currentDate.toLocaleString('default', { month: 'short' }),
            week: week
          })
        }
        
        cell.className = `heatmap-cell level-${this.getLevel(count)}`
        cell.dataset.date = dateStr
        cell.dataset.count = count
        cell.dataset.action = "mouseenter->calendar-heatmap#showTooltip mouseleave->calendar-heatmap#hideTooltip"
        
        // Mark future dates
        if (currentDate > today) {
          cell.className = "heatmap-cell level-future"
        }
        
        weekColumn.appendChild(cell)
        currentDate.setDate(currentDate.getDate() + 1)
      }
      
      weeksContainer.appendChild(weekColumn)
    }
    
    // Create month labels with proper positioning
    // Cell size: 9px + 1px gap = 10px on mobile, 12px + 2px gap = 14px on desktop
    const isMobile = window.innerWidth < 576
    const cellWidth = isMobile ? 10 : 14
    monthPositions.forEach((pos, index) => {
      const monthLabel = document.createElement("span")
      monthLabel.className = "heatmap-month-label"
      monthLabel.textContent = pos.month
      monthLabel.style.left = `${pos.week * cellWidth}px`
      monthLabels.appendChild(monthLabel)
    })
    
    // Assemble grid area
    gridArea.appendChild(monthLabels)
    gridArea.appendChild(weeksContainer)
    
    // Assemble wrapper
    wrapper.appendChild(dayLabels)
    wrapper.appendChild(gridArea)
    
    container.appendChild(wrapper)
    
    // Add legend
    const legend = document.createElement("div")
    legend.className = "heatmap-legend"
    legend.innerHTML = `
      <span class="text-muted small me-2">Less</span>
      <div class="heatmap-cell level-0"></div>
      <div class="heatmap-cell level-1"></div>
      <div class="heatmap-cell level-2"></div>
      <div class="heatmap-cell level-3"></div>
      <div class="heatmap-cell level-4"></div>
      <span class="text-muted small ms-2">More</span>
    `
    container.appendChild(legend)
  }

  formatDate(date) {
    return date.toISOString().split('T')[0]
  }

  getLevel(count) {
    if (count === 0) return 0
    if (count === 1) return 1
    if (count === 2) return 2
    if (count <= 4) return 3
    return 4
  }

  showTooltip(event) {
    const cell = event.target
    const date = cell.dataset.date
    const count = parseInt(cell.dataset.count)
    
    if (!this.hasTooltipTarget) return
    
    const tooltip = this.tooltipTarget
    const formattedDate = new Date(date + 'T00:00:00').toLocaleDateString('en-US', { 
      weekday: 'short', 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    })
    
    let text = count === 0 
      ? `No workouts on ${formattedDate}`
      : `${count} workout${count > 1 ? 's' : ''} on ${formattedDate}`
    
    tooltip.textContent = text
    tooltip.classList.remove("d-none")
    
    // Position tooltip
    const rect = cell.getBoundingClientRect()
    const containerRect = this.containerTarget.getBoundingClientRect()
    tooltip.style.left = `${rect.left - containerRect.left + rect.width / 2}px`
    tooltip.style.top = `${rect.top - containerRect.top - 30}px`
  }

  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("d-none")
    }
  }
}
