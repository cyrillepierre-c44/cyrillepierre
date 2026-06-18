import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabButton", "sourcePanel", "submitButton", "overlay", "realisationField"]

  connect() {
    this.toggleRealisationField()
  }

  selectKind() {
    this.toggleRealisationField()
  }

  toggleRealisationField() {
    if (!this.hasRealisationFieldTarget) return

    const checked = this.element.querySelector('input[name="generation[kind]"]:checked')
    this.realisationFieldTarget.classList.toggle("d-none", !checked || checked.value !== "linkedin_post")
  }

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
