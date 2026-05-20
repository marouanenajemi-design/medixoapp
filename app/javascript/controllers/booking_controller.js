import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "submitBtn",
    "doctorId", "dateInput", "timeInput",
    "doctorCard",
    "step1", "step1Body", "step1Summary", "step1Edit",
    "step2", "step2Body", "step2Summary", "step2Edit",
    "step3", "step3Body", "step3Summary", "step3Edit",
    "step4",
    "calTitle", "calGrid", "prevMonthBtn",
    "slotsLoader", "slotsGrid",
    "summaryText"
  ]

  connect() {
    this.meta         = JSON.parse(document.getElementById("mx-booking-meta")?.textContent || "{}")
    this.selectedDoc  = null
    this.selectedDate = null
    this.selectedTime = null
    this.viewYear     = new Date().getFullYear()
    this.viewMonth    = new Date().getMonth()
    this.locale       = this.meta.locale || "en"
    this.slotsUrl     = this.meta.slotsUrl || ""
  }

  // ── Step 1: Doctor selection ──────────────────────────────────────
  selectDoctor(event) {
    const card = event.currentTarget
    this.selectedDoc = {
      id:        card.dataset.doctorId,
      name:      card.dataset.doctorName,
      specialty: card.dataset.doctorSpecialty
    }

    this.doctorCardTargets.forEach(c => c.classList.remove("selected"))
    card.classList.add("selected")

    this.doctorIdTarget.value = this.selectedDoc.id
    this.markDone(1, this.selectedDoc.name + " — " + this.selectedDoc.specialty)
    this.showStep(2)
    this.renderCalendar()
  }

  // ── Step 2: Date selection ────────────────────────────────────────
  renderCalendar() {
    const today      = new Date()
    const year       = this.viewYear
    const month      = this.viewMonth
    const firstDay   = new Date(year, month, 1).getDay()
    const daysInMonth = new Date(year, month + 1, 0).getDate()

    const monthName = new Date(year, month, 1).toLocaleString(this.locale, { month: "long", year: "numeric" })
    this.calTitleTarget.textContent = monthName

    const isPrevDisabled = year < today.getFullYear() || (year === today.getFullYear() && month <= today.getMonth())
    this.prevMonthBtnTarget.disabled = isPrevDisabled

    // Day-of-week headers (Mon first)
    const dowLabels = this.locale.startsWith("fr")
      ? ["Lu", "Ma", "Me", "Je", "Ve", "Sa", "Di"]
      : ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    let html = dowLabels.map(d => `<div class="booking-cal-dow">${d}</div>`).join("")

    // Offset: JS getDay() 0=Sun; we want Mon=0
    const offset = (firstDay + 6) % 7
    for (let i = 0; i < offset; i++) {
      html += `<button type="button" class="booking-cal-day empty" disabled></button>`
    }

    for (let d = 1; d <= daysInMonth; d++) {
      const date    = new Date(year, month, d)
      const dateStr = this.toDateStr(date)
      const isToday = this.toDateStr(today) === dateStr
      const isPast  = date < today && !isToday
      const isSat   = date.getDay() === 6
      const isSun   = date.getDay() === 0
      const isWeekend = isSat || isSun
      const isSelected = dateStr === this.selectedDate

      let cls = "booking-cal-day"
      if (isToday)    cls += " today"
      if (isPast)     cls += " past"
      if (isWeekend)  cls += " weekend"
      if (isSelected) cls += " selected"

      const disabled = isPast || isWeekend ? "disabled" : ""
      html += `<button type="button" class="${cls}" ${disabled}
                 data-date="${dateStr}"
                 data-action="click->booking#selectDate">${d}</button>`
    }

    this.calGridTarget.innerHTML = html
  }

  prevMonth() {
    const today = new Date()
    if (this.viewYear <= today.getFullYear() && this.viewMonth <= today.getMonth()) return
    this.viewMonth--
    if (this.viewMonth < 0) { this.viewMonth = 11; this.viewYear-- }
    this.renderCalendar()
  }

  nextMonth() {
    const limit = new Date()
    limit.setMonth(limit.getMonth() + 3)
    const next = new Date(this.viewYear, this.viewMonth + 1, 1)
    if (next > limit) return
    this.viewMonth++
    if (this.viewMonth > 11) { this.viewMonth = 0; this.viewYear++ }
    this.renderCalendar()
  }

  async selectDate(event) {
    const btn  = event.currentTarget
    const date = btn.dataset.date
    if (!date) return

    this.selectedDate = date
    this.selectedTime = null
    this.timeInputTarget.value = ""

    this.calGridTarget.querySelectorAll(".booking-cal-day").forEach(b => b.classList.remove("selected"))
    btn.classList.add("selected")
    this.dateInputTarget.value = date

    const label = new Date(date + "T12:00:00").toLocaleDateString(this.locale, { weekday: "long", month: "long", day: "numeric" })
    this.markDone(2, label)
    this.showStep(3)

    await this.fetchSlots(date)
  }

  // ── Step 3: Time slots ────────────────────────────────────────────
  async fetchSlots(date) {
    this.slotsLoaderTarget.classList.add("active")
    this.slotsGridTarget.innerHTML = ""

    const params  = new URLSearchParams({ doctor_id: this.selectedDoc.id, date })
    const fetchUrl = `${this.slotsUrl}?${params.toString()}`
    console.log("[booking] fetchSlots →", fetchUrl, "doctor:", this.selectedDoc, "date:", date)

    try {
      const resp = await fetch(fetchUrl, { headers: { Accept: "application/json" } })
      console.log("[booking] slots response:", resp.status, resp.headers.get("content-type"))

      if (!resp.ok) {
        console.error("[booking] slots request failed:", resp.status)
        this.slotsGridTarget.innerHTML = `<div class="booking-no-slots"><i class="bi bi-exclamation-circle"></i> Could not load slots. Please try again.</div>`
        return
      }

      const data = await resp.json()
      console.log("[booking] slots data:", data)
      this.renderSlots(data.slots || [])
    } catch (err) {
      console.error("[booking] fetchSlots error:", err)
      this.slotsGridTarget.innerHTML = `<div class="booking-no-slots"><i class="bi bi-exclamation-circle"></i> Could not load slots. Please try again.</div>`
    } finally {
      this.slotsLoaderTarget.classList.remove("active")
    }
  }

  renderSlots(slots) {
    if (slots.length === 0) {
      this.slotsGridTarget.innerHTML = `
        <div class="booking-no-slots">
          <i class="bi bi-calendar-x"></i>
          No available times for this date. Please choose another day.
        </div>`
      return
    }

    this.slotsGridTarget.innerHTML = slots.map(t => `
      <button type="button" class="booking-time-chip"
              data-action="click->booking#selectTime"
              data-time="${t}">${t}</button>
    `).join("")
  }

  selectTime(event) {
    const chip = event.currentTarget
    const time = chip.dataset.time

    this.slotsGridTarget.querySelectorAll(".booking-time-chip").forEach(c => c.classList.remove("selected"))
    chip.classList.add("selected")

    this.selectedTime     = time
    this.timeInputTarget.value = time

    this.markDone(3, time)
    this.showStep(4)
    this.updateSummary()
  }

  // ── Step 4: Summary ───────────────────────────────────────────────
  updateSummary() {
    const date  = this.selectedDate
      ? new Date(this.selectedDate + "T12:00:00").toLocaleDateString(this.locale, { weekday: "short", month: "short", day: "numeric" })
      : "—"
    const parts = [
      this.selectedDoc?.name,
      date,
      this.selectedTime
    ].filter(Boolean)

    if (this.hasSummaryTextTarget) {
      this.summaryTextTarget.textContent = parts.join(" · ")
    }
  }

  submitForm(event) {
    if (!this.doctorIdTarget.value || !this.dateInputTarget.value || !this.timeInputTarget.value) {
      event.preventDefault()
      alert("Please complete all steps before submitting.")
      return
    }
    const btn = this.submitBtnTarget
    btn.disabled = true
    btn.innerHTML = `<div class="booking-spinner" style="border-top-color:white;width:18px;height:18px;"></div> Submitting…`
  }

  // ── Navigation helpers ────────────────────────────────────────────
  backToStep(event) {
    const step = parseInt(event.currentTarget.dataset.step)
    if (!event.currentTarget.closest(".booking-step").classList.contains("booking-step--done")) return
    this.showStep(step)
    this.undoneFrom(step)
  }

  showStep(n) {
    const el = this[`step${n}Target`]
    el.classList.remove("booking-step--hidden")
    setTimeout(() => el.scrollIntoView({ behavior: "smooth", block: "nearest" }), 60)
  }

  markDone(n, summary) {
    const step    = this[`step${n}Target`]
    const sumEl   = this[`step${n}SummaryTarget`]
    const editBtn = this[`step${n}EditTarget`]

    step.classList.add("booking-step--done")
    sumEl.textContent    = summary
    sumEl.style.display  = ""
    editBtn.style.display = ""
  }

  undoneFrom(n) {
    for (let i = n; i <= 4; i++) {
      const step = this[`step${i}Target`]
      if (!step) continue
      step.classList.remove("booking-step--done")
      const sumEl  = this[`step${i}SummaryTarget`]
      const editEl = this[`step${i}EditTarget`]
      if (sumEl)  { sumEl.textContent = ""; sumEl.style.display = "none"; }
      if (editEl) { editEl.style.display = "none"; }
      if (i > n) step.classList.add("booking-step--hidden")
    }
  }

  // ── Utility ───────────────────────────────────────────────────────
  toDateStr(date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
  }
}
