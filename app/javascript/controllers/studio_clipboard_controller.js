import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy(event) {
    const text = this.sourceTarget.textContent
    const button = event.currentTarget
    const original = button.innerHTML

    navigator.clipboard.writeText(text).then(() => {
      button.innerHTML = '<i class="fa-solid fa-check"></i>'
      setTimeout(() => { button.innerHTML = original }, 2000)
    })
  }
}
