import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    frame: String
  }

  visit(event) {
    if (!this.hasUrlValue || !window.Turbo) return

    event.preventDefault()
    Turbo.visit(this.urlValue, this.hasFrameValue ? { frame: this.frameValue } : {})
  }
}
