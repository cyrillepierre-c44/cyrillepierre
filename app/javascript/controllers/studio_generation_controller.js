import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabButton", "sourcePanel", "submitButton", "overlay", "realisationField", "progressText"]

  // Generating an article with a visual is two sequential backend calls (text, then image) in a
  // single synchronous request — there is no real-time progress to poll, so we approximate it by
  // switching the overlay's label after a fixed delay roughly matching how long text generation
  // usually takes, just to tell the user the image step is what's taking the rest of the time.
  static TEXT_STAGE_DURATION_MS = 12000

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
      this.announceStages(event.target)
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.value = "Génération en cours…"
    }
  }

  announceStages(form) {
    if (!this.hasProgressTextTarget) return

    const generateVisual = form.querySelector('input[name="generation[generate_visual]"]')
    if (!generateVisual || !generateVisual.checked) return

    this.progressTextTarget.textContent = "Étape 1/2 : génération du texte…"
    setTimeout(() => {
      this.progressTextTarget.textContent = "Étape 2/2 : génération du visuel…"
    }, this.constructor.TEXT_STAGE_DURATION_MS)
  }

  showOverlay() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("d-none")
  }
}
