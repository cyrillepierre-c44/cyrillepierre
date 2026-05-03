import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const items = this.element.querySelectorAll(".reveal")
    if (items.length === 0) return

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add("revealed")
          observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.08, rootMargin: "0px 0px -80px 0px" })

    items.forEach(item => observer.observe(item))
  }
}
