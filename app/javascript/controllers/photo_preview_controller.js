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

    // Store reference globally so modal controller can find it
    window._activePhotoPreview = this

    // Force reflow then show
    modal.offsetHeight
    modal.style.opacity = '1'

    // Close on backdrop click
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.closest('.modal-dialog') === null) {
        this.close()
      }
    })

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
    modal.className = 'photo-preview-modal'
    modal.style.cssText = 'position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.95); z-index: 9999; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.2s ease;'
    modal.setAttribute('tabindex', '-1')

    modal.innerHTML = `
      <div style="position: relative; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center;">
        <div style="position: absolute; top: 0; left: 0; right: 0; display: flex; justify-content: space-between; align-items: center; padding: 1rem; z-index: 10;">
          <span class="text-white small photo-counter">${this.currentPhotoIndex + 1} / ${this.urlsValue.length}</span>
          <button type="button" class="btn btn-sm btn-dark photo-close-btn" style="width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center;">
            <i class="bi bi-x-lg"></i>
          </button>
        </div>
        <div style="position: relative; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; padding: 60px 16px 16px;">
          ${this.urlsValue.length > 1 ? `
            <button class="btn btn-dark photo-prev-btn" style="position: absolute; left: 12px; width: 44px; height: 44px; border-radius: 50%; z-index: 10; display: flex; align-items: center; justify-content: center;">
              <i class="bi bi-chevron-left"></i>
            </button>
          ` : ''}
          
          <img src="${this.urlsValue[0]}" 
               class="photo-display" 
               style="max-height: 85vh; max-width: 90vw; object-fit: contain; transition: opacity 0.15s ease;"
               alt="Machine photo">
          
          ${this.urlsValue.length > 1 ? `
            <button class="btn btn-dark photo-next-btn" style="position: absolute; right: 12px; width: 44px; height: 44px; border-radius: 50%; z-index: 10; display: flex; align-items: center; justify-content: center;">
              <i class="bi bi-chevron-right"></i>
            </button>
          ` : ''}
        </div>
      </div>
    `

    // Wire up button events directly
    const closeBtn = modal.querySelector('.photo-close-btn')
    if (closeBtn) closeBtn.addEventListener('click', (e) => { e.stopPropagation(); this.close() })
    
    const prevBtn = modal.querySelector('.photo-prev-btn')
    if (prevBtn) prevBtn.addEventListener('click', (e) => { e.stopPropagation(); this.previousPhoto() })
    
    const nextBtn = modal.querySelector('.photo-next-btn')
    if (nextBtn) nextBtn.addEventListener('click', (e) => { e.stopPropagation(); this.nextPhoto() })

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

    this.modal.style.opacity = '0'
    setTimeout(() => {
      if (this.modal) {
        this.modal.remove()
        this.modal = null
      }
    }, 200)

    window._activePhotoPreview = null

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
