import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabButton", "sourcePanel", "submitButton", "overlay"]

  selectSource(event) {
    const source = event.currentTarget.dataset.source

    this.tabButtonTargets.forEach((button) => {
      button.classList.toggle("studio-source-tab--active", button.dataset.source === source)
    })

    this.sourcePanelTargets.forEach((panel) => {
      panel.classList.toggle("d-none", panel.dataset.source !== source)
    })
  }

  submitting(event) {
    if (!event.target.checkValidity || event.target.checkValidity()) {
      this.showOverlay()
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.value = "Génération en cours…"
    }
  }

  showOverlay() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("d-none")
  }
}
