import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy(event) {
    const text = this.sourceTarget.textContent
    const button = event.currentTarget
    const original = button.textContent

    navigator.clipboard.writeText(text).then(() => {
      button.textContent = "✓ Copié !"
      setTimeout(() => { button.textContent = original }, 2000)
    })
  }
}
