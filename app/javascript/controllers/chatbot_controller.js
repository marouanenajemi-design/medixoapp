import { Controller } from "@hotwired/stimulus"

// Handles loading state and auto-scroll for the AI chatbot.
//
// Targets:
//   thread  – the scrollable message list container
//   input   – the text field
//   submit  – the submit button label span
//   spinner – the animated dots shown while waiting
//   thinking – the "AI is thinking…" row appended to the thread
export default class extends Controller {
  static targets = ["thread", "input", "submit", "spinner", "thinking"]

  connect() {
    this.scrollToBottom()
  }

  // Called by data-action="turbo:submit-start->chatbot#showLoading" on the form.
  showLoading(event) {
    if (this.hasSubmitTarget)  this.submitTarget.hidden  = true
    if (this.hasSpinnerTarget) this.spinnerTarget.hidden = false
    if (this.hasThinkingTarget) this.thinkingTarget.hidden = false
    this.scrollToBottom()
  }

  // Called by data-action="turbo:submit-end->chatbot#hideLoading" on the form.
  hideLoading(event) {
    if (this.hasSubmitTarget)  this.submitTarget.hidden  = false
    if (this.hasSpinnerTarget) this.spinnerTarget.hidden = true
    if (this.hasThinkingTarget) this.thinkingTarget.hidden = true
    if (this.hasInputTarget)   this.inputTarget.value   = ""
    // Wait one frame for Turbo to finish patching the DOM before scrolling.
    requestAnimationFrame(() => this.scrollToBottom())
  }

  scrollToBottom() {
    if (this.hasThreadTarget) {
      this.threadTarget.scrollTop = this.threadTarget.scrollHeight
    }
  }
}
