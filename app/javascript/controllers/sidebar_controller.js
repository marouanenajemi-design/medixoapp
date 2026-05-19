import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.close()
  }

  disconnect() {
    this.close()
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    document.body.classList.add("sidebar-open")
  }

  close() {
    document.body.classList.remove("sidebar-open")
  }

  closeFromSidebar(event) {
    if (window.innerWidth > 991) return
    if (!event.target.closest("a, form, button")) return

    this.close()
  }

  handleResize() {
    if (window.innerWidth > 991) {
      this.close()
    }
  }

  isOpen() {
    return document.body.classList.contains("sidebar-open")
  }
}
