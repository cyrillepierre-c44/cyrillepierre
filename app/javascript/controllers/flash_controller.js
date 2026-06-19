import { Controller } from "@hotwired/stimulus"

// Auto-dismisses the green/red flash notice after a delay, instead of leaving it on screen
// until the next page navigation removes it.
export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("alert-flash--hide")
    this.element.addEventListener("animationend", () => this.element.remove(), { once: true })
  }
}
