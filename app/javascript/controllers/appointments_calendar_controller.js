import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    locale: String,
    events: Array,
    buttonText: Object,
    newUrl: String
  }

  connect() {
    console.log("CALENDAR CONTROLLER CONNECTED")
    console.log("FullCalendar:", window.FullCalendar)
    console.log("localeValue:", this.localeValue)
    console.log("eventsValue:", this.eventsValue)
    console.log("buttonTextValue:", this.buttonTextValue)
    console.log("newUrlValue:", this.newUrlValue)

    if (!window.FullCalendar) {
      console.log("FullCalendar not loaded")
      return
    }

    const locale = this.hasLocaleValue && this.localeValue ? this.localeValue : "en"
    console.log("resolved locale:", locale)

    this.calendar = new window.FullCalendar.Calendar(this.element, {
      locale: locale,
      initialView: "dayGridMonth",
      headerToolbar: window.innerWidth < 768 ? {
        left: "prev,next",
        center: "title",
        right: "dayGridMonth,timeGridWeek"
      } : {
        left: "prev,next today",
        center: "title",
        right: "dayGridMonth,timeGridWeek,timeGridDay"
      },
      buttonText: this.buttonTextValue,
      height: window.innerWidth < 768 ? "auto" : 720,
      navLinks: true,
      editable: false,
      selectable: true,
      eventTimeFormat: {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
      },
      dateClick: (info) => {
        window.location.href = `${this.newUrlValue}?date=${info.dateStr}`
      },
      events: this.eventsValue,
      eventClick: (info) => {
        info.jsEvent.preventDefault()
        if (info.event.url) {
          window.location.href = info.event.url
        }
      }
    })

    console.log("ABOUT TO RENDER CALENDAR")
    this.calendar.render()
    console.log("CALENDAR RENDERED")
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
      this.calendar = null
    }
  }
}
