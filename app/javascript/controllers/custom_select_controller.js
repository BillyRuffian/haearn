import { Controller } from "@hotwired/stimulus"

// Replaces native <select> with a custom stylable dropdown
// Connect with data-controller="custom-select" on a select element
export default class extends Controller {
  static values = { open: Boolean }

  connect() {
    this.createCustomDropdown()
  }

  disconnect() {
    if (this.wrapper) {
      this.wrapper.remove()
    }
    this.element.style.display = ""
  }

  createCustomDropdown() {
    // Hide the original select
    this.element.style.display = "none"

    // Create wrapper
    this.wrapper = document.createElement("div")
    this.wrapper.className = "custom-select-wrapper"
    this.wrapper.style.position = "relative"

    // Create the visible button - preserve size classes from original select
    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.className = "custom-select-button"

    // Copy size classes from original element
    if (this.element.classList.contains("form-select-lg")) {
      this.button.classList.add("form-select-lg")
    }
    if (this.element.classList.contains("form-select-sm")) {
      this.button.classList.add("form-select-sm")
    }

    this.updateButtonText()

    // Create dropdown
    this.dropdown = document.createElement("div")
    this.dropdown.className = "custom-select-dropdown"
    this.dropdown.style.display = "none"

    // Populate options
    this.populateOptions()

    // Assemble
    this.wrapper.appendChild(this.button)
    this.wrapper.appendChild(this.dropdown)
    this.element.insertAdjacentElement("afterend", this.wrapper)

    // Event listeners
    this.button.addEventListener("click", this.toggle.bind(this))
    document.addEventListener("click", this.handleClickOutside.bind(this))
  }

  populateOptions() {
    this.dropdown.innerHTML = ""
    Array.from(this.element.options).forEach((option, index) => {
      const item = document.createElement("div")
      item.className = "custom-select-option"
      item.textContent = option.textContent
      item.dataset.value = option.value
      item.dataset.index = index

      if (option.selected) {
        item.classList.add("selected")
      }

      item.addEventListener("click", () => this.selectOption(index))
      this.dropdown.appendChild(item)
    })
  }

  updateButtonText() {
    const selected = this.element.options[this.element.selectedIndex]
    this.button.textContent = selected ? selected.textContent : "Select..."
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.dropdown.style.display === "none") {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.dropdown.style.display = "block"
    this.wrapper.classList.add("open")
  }

  close() {
    this.dropdown.style.display = "none"
    this.wrapper.classList.remove("open")
  }

  selectOption(index) {
    this.element.selectedIndex = index
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
    this.updateButtonText()
    this.populateOptions() // Refresh to update selected state
    this.close()
  }

  handleClickOutside(event) {
    if (!this.wrapper.contains(event.target)) {
      this.close()
    }
  }
}
