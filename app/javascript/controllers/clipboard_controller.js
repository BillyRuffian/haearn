import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
// Copies text to clipboard, either from a URL endpoint or static text
// Uses fallback method for iOS Safari compatibility
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

      // Prefer static text over URL fetching for iOS PWA compatibility
      // iOS requires clipboard operations to happen synchronously within user gesture
      if (this.hasTextValue) {
        textToCopy = this.textValue
      } else if (this.hasUrlValue && this.urlValue) {
        // Fetch text from URL (may not work reliably on iOS PWA)
        const response = await fetch(this.urlValue, {
          headers: { 'Accept': 'application/json' }
        })
        const data = await response.json()
        textToCopy = data.text
      } else {
        throw new Error("No text or URL provided")
      }

      // Try modern Clipboard API first, fallback to legacy method for iOS
      const success = await this.copyToClipboard(textToCopy)

      if (!success) {
        throw new Error("Copy failed")
      }

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

  // Cross-browser clipboard copy with iOS Safari fallback
  async copyToClipboard(text) {
    // Try modern Clipboard API first
    if (navigator.clipboard && navigator.clipboard.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        return true
      } catch (err) {
        console.warn("Clipboard API failed, trying fallback:", err)
      }
    }

    // Fallback for iOS Safari and older browsers
    return this.fallbackCopyToClipboard(text)
  }

  // Legacy clipboard copy using textarea and execCommand
  // This works on iOS Safari where Clipboard API may fail
  fallbackCopyToClipboard(text) {
    const textArea = document.createElement("textarea")
    textArea.value = text

    // Avoid scrolling to bottom on iOS
    textArea.style.top = "0"
    textArea.style.left = "0"
    textArea.style.position = "fixed"
    textArea.style.width = "2em"
    textArea.style.height = "2em"
    textArea.style.padding = "0"
    textArea.style.border = "none"
    textArea.style.outline = "none"
    textArea.style.boxShadow = "none"
    textArea.style.background = "transparent"
    // Prevent zoom on iOS
    textArea.style.fontSize = "16px"

    document.body.appendChild(textArea)

    // iOS specific handling
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)

    if (isIOS) {
      // iOS requires a range selection approach
      const range = document.createRange()
      range.selectNodeContents(textArea)
      const selection = window.getSelection()
      selection.removeAllRanges()
      selection.addRange(range)
      textArea.setSelectionRange(0, text.length)
    } else {
      textArea.focus()
      textArea.select()
    }

    let success = false
    try {
      success = document.execCommand('copy')
    } catch (err) {
      console.error('execCommand copy failed:', err)
    }

    document.body.removeChild(textArea)
    return success
  }
}
