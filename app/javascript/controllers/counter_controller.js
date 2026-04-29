import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["number"]
  static values  = {
    end:      Number,
    duration: { type: Number, default: 1800 },
    suffix:   { type: String, default: "" }
  }

  connect() {
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        this.animate()
        observer.disconnect()
      }
    }, { threshold: 0.5 })
    observer.observe(this.element)
  }

  animate() {
    const end      = this.endValue
    const duration = this.durationValue
    const suffix   = this.suffixValue
    const start    = performance.now()

    const step = (now) => {
      const progress = Math.min((now - start) / duration, 1)
      const eased    = 1 - Math.pow(1 - progress, 3)
      const current  = Math.round(end * eased)
      this.numberTarget.textContent = current + suffix
      if (progress < 1) requestAnimationFrame(step)
    }

    requestAnimationFrame(step)
  }
}
