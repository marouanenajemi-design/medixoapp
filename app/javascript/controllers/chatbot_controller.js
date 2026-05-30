import { Controller } from "@hotwired/stimulus"

// Full-page chatbot controller.
//
// Intercepts form submission to give Claude/ChatGPT-like instant feedback:
//   1. Paints the user bubble immediately (no server round-trip).
//   2. Paints a "thinking" bubble with animated dots.
//   3. POSTs to the server via fetch() with Turbo Stream accept header.
//   4. Server returns a Turbo Stream that appends the real AI bubble.
//   5. We remove the thinking bubble and scroll down.
//
// Targets
//   thread   – scrollable message list  (id="chat-thread")
//   input    – text <input>
//   form     – the <form> element
//   sendIcon – the ↑ icon inside the send button (hidden while loading)
//   spinner  – the small spinner inside the send button (shown while loading)
export default class extends Controller {
  static targets = ["thread", "input", "form", "sendIcon", "spinner"]

  connect() {
    this.#busy = false
    this.scrollToBottom()
  }

  // Bound to data-action="submit->chatbot#submit" on the form.
  submit(event) {
    event.preventDefault()

    const query = this.inputTarget.value.trim()
    if (!query || this.#busy) return

    this.#busy = true
    this.inputTarget.value = ""
    this.inputTarget.disabled = true

    // ── 1. Paint user bubble immediately ────────────────────────────────────
    this.#appendUserBubble(query)

    // ── 2. Paint thinking bubble ─────────────────────────────────────────────
    const thinkingId = this.#appendThinkingBubble()

    // ── 3. Show loading state ─────────────────────────────────────────────────
    this.#setSending(true)
    this.scrollToBottom()

    // ── 4. POST to server ─────────────────────────────────────────────────────
    const csrf = document.querySelector('meta[name="csrf-token"]').content
    const body = new FormData()
    body.append("query", query)

    fetch(this.formTarget.action, {
      method:  "POST",
      headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": csrf },
      body
    })
    .then(r => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`)
      return r.text()
    })
    .then(html => {
      // ── 5. Remove thinking bubble, paint AI bubble via Turbo Stream ─────────
      document.getElementById(thinkingId)?.remove()
      Turbo.renderStreamMessage(html)
      this.#done()
    })
    .catch(() => {
      document.getElementById(thinkingId)?.remove()
      this.#appendErrorBubble(
        this.element.dataset.errorMessage || "Service unavailable. Please try again."
      )
      this.#done()
    })
  }

  scrollToBottom() {
    if (!this.hasThreadTarget) return
    this.threadTarget.scrollTo({ top: this.threadTarget.scrollHeight, behavior: "smooth" })
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  #busy = false

  #done() {
    this.#setSending(false)
    this.inputTarget.disabled = false
    this.inputTarget.focus()
    this.#busy = false
    requestAnimationFrame(() => this.scrollToBottom())
  }

  #setSending(on) {
    if (this.hasSendIconTarget) this.sendIconTarget.hidden = on
    if (this.hasSpinnerTarget)  this.spinnerTarget.hidden  = !on
  }

  #appendUserBubble(query) {
    const time = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    this.threadTarget.insertAdjacentHTML("beforeend", `
      <div class="cmsg cmsg--user">
        <div class="cmsg-bubble cmsg-bubble--user">${this.#esc(query)}</div>
        <div class="cmsg-ts">${time}</div>
      </div>`)
  }

  #appendThinkingBubble() {
    const id = `thinking_${Date.now()}`
    this.threadTarget.insertAdjacentHTML("beforeend", `
      <div class="cmsg cmsg--ai" id="${id}">
        <div class="cmsg-row">
          <div class="cmsg-avatar"><i class="bi bi-stars"></i></div>
          <div class="cmsg-bubble cmsg-bubble--ai cmsg-bubble--thinking">
            <span class="thinking-text">MedixoApp AI is thinking</span>
            <span class="thinking-dots"><span></span><span></span><span></span></span>
          </div>
        </div>
      </div>`)
    return id
  }

  #appendErrorBubble(message) {
    this.threadTarget.insertAdjacentHTML("beforeend", `
      <div class="cmsg cmsg--ai">
        <div class="cmsg-row">
          <div class="cmsg-avatar"><i class="bi bi-stars"></i></div>
          <div class="cmsg-bubble cmsg-bubble--ai cmsg-bubble--error">${this.#esc(message)}</div>
        </div>
      </div>`)
  }

  #esc(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
