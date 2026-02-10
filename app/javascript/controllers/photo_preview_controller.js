import { Controller } from "@hotwired/stimulus"

// Photo preview modal controller
// Shows machine photos in a full-screen modal when thumbnail is clicked
// Supports multiple photos with swipe navigation
export default class extends Controller {
  static values = {
    urls: Array  // Array of photo URLs to display
  }

  show(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.urlsValue || this.urlsValue.length === 0) return

    // Create modal HTML
    const modal = this.createModal()
    document.body.appendChild(modal)

    // Show modal
    setTimeout(() => modal.classList.add('show'), 10)

    // Setup keyboard navigation
    this.keyboardHandler = (e) => {
      if (e.key === 'Escape') this.close()
      if (e.key === 'ArrowLeft') this.previousPhoto()
      if (e.key === 'ArrowRight') this.nextPhoto()
    }
    document.addEventListener('keydown', this.keyboardHandler)
  }

  createModal() {
    this.currentPhotoIndex = 0

    const modal = document.createElement('div')
    modal.className = 'modal fade photo-preview-modal'
    modal.style.cssText = 'display: block; background: rgba(0,0,0,0.95);'
    modal.setAttribute('data-controller', 'photo-preview-modal')
    modal.setAttribute('tabindex', '-1')

    modal.innerHTML = `
      <div class="modal-dialog modal-dialog-centered modal-fullscreen">
        <div class="modal-content bg-transparent border-0">
          <div class="modal-header border-0 position-absolute w-100" style="z-index: 1050;">
            <h5 class="modal-title text-white">
              <span class="photo-counter">${this.currentPhotoIndex + 1} / ${this.urlsValue.length}</span>
            </h5>
            <button type="button" class="btn-close btn-close-white" data-action="click->photo-preview-modal#close"></button>
          </div>
          <div class="modal-body d-flex align-items-center justify-content-center p-0">
            <div class="position-relative w-100 h-100 d-flex align-items-center justify-content-center">
              ${this.urlsValue.length > 1 ? `
                <button class="btn btn-dark position-absolute start-0 ms-3 rounded-circle" 
                        style="width: 48px; height: 48px; z-index: 1050;"
                        data-action="click->photo-preview-modal#previous">
                  <i class="bi bi-chevron-left"></i>
                </button>
              ` : ''}
              
              <img src="${this.urlsValue[0]}" 
                   class="img-fluid photo-display" 
                   style="max-height: 90vh; max-width: 90vw; object-fit: contain;"
                   alt="Machine photo">
              
              ${this.urlsValue.length > 1 ? `
                <button class="btn btn-dark position-absolute end-0 me-3 rounded-circle" 
                        style="width: 48px; height: 48px; z-index: 1050;"
                        data-action="click->photo-preview-modal#next">
                  <i class="bi bi-chevron-right"></i>
                </button>
              ` : ''}
            </div>
          </div>
        </div>
      </div>
    `

    // Store reference to modal
    this.modal = modal

    // Setup touch gestures for mobile swipe
    if (this.urlsValue.length > 1) {
      this.setupTouchGestures(modal.querySelector('.photo-display'))
    }

    return modal
  }

  setupTouchGestures(element) {
    let touchStartX = 0
    let touchEndX = 0

    element.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].screenX
    })

    element.addEventListener('touchend', (e) => {
      touchEndX = e.changedTouches[0].screenX
      this.handleSwipe(touchStartX, touchEndX)
    })
  }

  handleSwipe(startX, endX) {
    const threshold = 50
    const diff = startX - endX

    if (Math.abs(diff) > threshold) {
      if (diff > 0) {
        // Swipe left - next photo
        this.nextPhoto()
      } else {
        // Swipe right - previous photo
        this.previousPhoto()
      }
    }
  }

  nextPhoto() {
    if (!this.modal || this.urlsValue.length <= 1) return

    this.currentPhotoIndex = (this.currentPhotoIndex + 1) % this.urlsValue.length
    this.updatePhoto()
  }

  previousPhoto() {
    if (!this.modal || this.urlsValue.length <= 1) return

    this.currentPhotoIndex = (this.currentPhotoIndex - 1 + this.urlsValue.length) % this.urlsValue.length
    this.updatePhoto()
  }

  updatePhoto() {
    const img = this.modal.querySelector('.photo-display')
    const counter = this.modal.querySelector('.photo-counter')

    // Fade out
    img.style.opacity = '0.3'

    setTimeout(() => {
      img.src = this.urlsValue[this.currentPhotoIndex]
      counter.textContent = `${this.currentPhotoIndex + 1} / ${this.urlsValue.length}`
      // Fade in
      img.style.opacity = '1'
    }, 150)
  }

  close() {
    if (!this.modal) return

    this.modal.classList.remove('show')
    setTimeout(() => {
      this.modal.remove()
      this.modal = null
    }, 300)

    // Remove keyboard listener
    if (this.keyboardHandler) {
      document.removeEventListener('keydown', this.keyboardHandler)
      this.keyboardHandler = null
    }
  }

  disconnect() {
    this.close()
  }
}

// Separate controller for modal instance
class PhotoPreviewModalController extends Controller {
  close() {
    // Find parent photo-preview controller and call its close method
    const photoPreviewElement = document.querySelector('[data-controller~="photo-preview"]')
    if (photoPreviewElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        photoPreviewElement, 
        'photo-preview'
      )
      if (controller) controller.close()
    } else {
      // Fallback: just remove the modal
      this.element.classList.remove('show')
      setTimeout(() => this.element.remove(), 300)
    }
  }

  next() {
    const photoPreviewElement = document.querySelector('[data-controller~="photo-preview"]')
    if (photoPreviewElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        photoPreviewElement,
        'photo-preview'
      )
      if (controller) controller.nextPhoto()
    }
  }

  previous() {
    const photoPreviewElement = document.querySelector('[data-controller~="photo-preview"]')
    if (photoPreviewElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        photoPreviewElement,
        'photo-preview'
      )
      if (controller) controller.previousPhoto()
    }
  }
}

// Register the modal controller
import { application } from "./application"
application.register("photo-preview-modal", PhotoPreviewModalController)
