import { Controller } from "@hotwired/stimulus"

// PWA Install Prompt Controller
// Shows a banner when the app can be installed to home screen
//
// Usage:
//   <div data-controller="install-prompt" class="d-none" data-install-prompt-target="banner">
//     <button data-action="click->install-prompt#install">Install App</button>
//     <button data-action="click->install-prompt#dismiss">Dismiss</button>
//   </div>
//
export default class extends Controller {
  static targets = ["banner"]
  static values = {
    dismissedKey: { type: String, default: "haearn-install-dismissed" }
  }

  connect() {
    this.deferredPrompt = null

    // Check if already dismissed
    if (this.isDismissed) return

    // Check if already installed
    if (this.isInstalled) return

    // Listen for beforeinstallprompt
    window.addEventListener("beforeinstallprompt", this.handleInstallPrompt.bind(this))

    // Track successful install
    window.addEventListener("appinstalled", this.handleInstalled.bind(this))
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.handleInstallPrompt.bind(this))
    window.removeEventListener("appinstalled", this.handleInstalled.bind(this))
  }

  get isDismissed() {
    return localStorage.getItem(this.dismissedKeyValue) === "true"
  }

  get isInstalled() {
    // Check if running in standalone mode (already installed)
    return window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
  }

  handleInstallPrompt(event) {
    // Prevent Chrome's mini-infobar
    event.preventDefault()

    // Store for later use
    this.deferredPrompt = event

    // Show our custom banner
    this.showBanner()
  }

  handleInstalled() {
    console.log("[InstallPrompt] App installed successfully")
    this.hideBanner()
    this.deferredPrompt = null
  }

  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("d-none")
      this.dispatch("shown")
    }
  }

  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("d-none")
    }
  }

  async install() {
    if (!this.deferredPrompt) {
      console.log("[InstallPrompt] No prompt available")
      return
    }

    // Show the install prompt
    this.deferredPrompt.prompt()

    // Wait for the user's response
    const { outcome } = await this.deferredPrompt.userChoice
    console.log(`[InstallPrompt] User response: ${outcome}`)

    // Clear the prompt
    this.deferredPrompt = null
    this.hideBanner()

    if (outcome === "accepted") {
      this.dispatch("installed")
    }
  }

  dismiss() {
    localStorage.setItem(this.dismissedKeyValue, "true")
    this.hideBanner()
    this.dispatch("dismissed")
  }
}
