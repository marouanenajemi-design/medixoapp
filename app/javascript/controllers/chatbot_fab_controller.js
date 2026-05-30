import { Controller } from "@hotwired/stimulus"

// Manages the floating AI button and its popover card.
//
// Targets
//   card   – the popover <div>
//   frame  – the <turbo-frame> inside the card
//
// The Turbo Frame has no src initially (data-lazy-src holds the URL).
// On first open we set src, triggering the frame to load.
export default class extends Controller {
  static targets = ["card", "frame"]

  connect() {
    this._outsideClick = this.#handleOutsideClick.bind(this)
    this._keydown      = this.#handleKeydown.bind(this)
    this._open = false
    this._frameLoaded = false
  }

  disconnect() {
    this.#unbindGlobal()
  }

  toggle(event) {
    event.stopPropagation()
    this._open ? this.close() : this.open()
  }

  open() {
    this._open = true
    this.cardTarget.hidden = false

    // Lazy-load the Turbo Frame on first open.
    if (!this._frameLoaded && this.hasFrameTarget) {
      const lazySrc = this.frameTarget.dataset.lazySrc
      if (lazySrc) this.frameTarget.setAttribute("src", lazySrc)
      this._frameLoaded = true
    }

    this.#bindGlobal()
  }

  close() {
    this._open = false
    this.cardTarget.hidden = true
    this.#unbindGlobal()
  }

  #handleOutsideClick(e) {
    if (!this.element.contains(e.target)) this.close()
  }

  #handleKeydown(e) {
    if (e.key === "Escape") this.close()
  }

  #bindGlobal() {
    document.addEventListener("click",   this._outsideClick)
    document.addEventListener("keydown", this._keydown)
  }

  #unbindGlobal() {
    document.removeEventListener("click",   this._outsideClick)
    document.removeEventListener("keydown", this._keydown)
  }
}
