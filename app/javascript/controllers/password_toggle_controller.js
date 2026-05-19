import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    if (!this.hasInputTarget || !this.hasButtonTarget) return

    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"
    this.buttonTarget.textContent = isPassword ? this.hideText : this.showText
  }

  get showText() {
    return this.buttonTarget.dataset.showText || "Show"
  }

  get hideText() {
    return this.buttonTarget.dataset.hideText || "Hide"
  }
}
