import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabButton", "sourcePanel", "submitButton"]

  selectSource(event) {
    const source = event.currentTarget.dataset.source

    this.tabButtonTargets.forEach((button) => {
      button.classList.toggle("studio-source-tab--active", button.dataset.source === source)
    })

    this.sourcePanelTargets.forEach((panel) => {
      panel.classList.toggle("d-none", panel.dataset.source !== source)
    })
  }

  submitting() {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.value = "Génération en cours…"
  }
}
