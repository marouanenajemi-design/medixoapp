import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper", "template"]

  add() {
    if (!this.hasWrapperTarget || !this.hasTemplateTarget) return

    const uniqueId = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", uniqueId)
    this.wrapperTarget.insertAdjacentHTML("beforeend", content)
  }

  handleWrapperClick(event) {
    if (!event.target.classList.contains("remove-medicine-btn")) return

    const block = event.target.closest(".prescription-item-block")
    if (!block) return

    const destroyField = block.querySelector(".destroy-flag")
    const idField = block.querySelector('input[name*="[id]"]')

    if (idField) {
      if (destroyField) destroyField.value = "1"
      block.style.display = "none"
    } else {
      block.remove()
    }
  }
}
