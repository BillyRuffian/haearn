import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
// Copies text to clipboard, either from a URL endpoint or static text
export default class extends Controller {
  static values = {
    url: String,      // URL to fetch text from
    text: String,     // Static text to copy
    successMessage: { type: String, default: "Copied to clipboard!" }
  }

  static targets = ["button"]

  async copy(event) {
    event.preventDefault()
    
    const button = this.hasButtonTarget ? this.buttonTarget : event.currentTarget
    const originalHtml = button.innerHTML
    
    try {
      let textToCopy
      
      if (this.hasUrlValue && this.urlValue) {
        // Fetch text from URL
        const response = await fetch(this.urlValue, {
          headers: { 'Accept': 'application/json' }
        })
        const data = await response.json()
        textToCopy = data.text
      } else if (this.hasTextValue) {
        textToCopy = this.textValue
      } else {
        throw new Error("No text or URL provided")
      }

      await navigator.clipboard.writeText(textToCopy)
      
      // Show success state
      button.innerHTML = '<i class="bi bi-check2 me-1"></i>Copied!'
      button.classList.remove('btn-outline-secondary')
      button.classList.add('btn-success')
      
      setTimeout(() => {
        button.innerHTML = originalHtml
        button.classList.remove('btn-success')
        button.classList.add('btn-outline-secondary')
      }, 2000)
      
    } catch (error) {
      console.error("Failed to copy:", error)
      
      // Show error state
      button.innerHTML = '<i class="bi bi-x me-1"></i>Failed'
      button.classList.remove('btn-outline-secondary')
      button.classList.add('btn-danger')
      
      setTimeout(() => {
        button.innerHTML = originalHtml
        button.classList.remove('btn-danger')
        button.classList.add('btn-outline-secondary')
      }, 2000)
    }
  }
}
