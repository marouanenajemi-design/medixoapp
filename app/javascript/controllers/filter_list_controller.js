import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "empty"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.hasInputTarget ? this.inputTarget.value.toLowerCase().trim() : ""
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const searchableText = (row.dataset.filterListSearchableValue || "").toLowerCase()
      const matches = searchableText.includes(query)

      row.style.display = matches ? "" : "none"
      if (matches) visibleCount += 1
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.style.display = visibleCount === 0 ? "block" : "none"
    }
  }
}
