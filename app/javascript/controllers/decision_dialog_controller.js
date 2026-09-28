import { Controller } from "@hotwired/stimulus"

// Boîte de confirmation avec raison (Retenir / Écarter un signal, Supprimer une fiche).
// Le bouton déclencheur porte l'adresse, la méthode HTTP et les libellés ; le formulaire du
// <dialog> est unique par page et se reconfigure à l'ouverture. La raison saisie part avec la
// requête et nourrit la mémoire de tri que la routine du lundi relit.
export default class extends Controller {
  static targets = ["dialog", "form", "method", "title", "reason", "submit"]

  open(event) {
    const { url, method, title, submit, placeholder } = event.currentTarget.dataset
    this.formTarget.action = url
    this.methodTarget.value = method || "patch"
    this.titleTarget.textContent = title || "Confirmer"
    this.submitTarget.textContent = submit || "Confirmer"
    this.reasonTarget.value = ""
    if (placeholder) this.reasonTarget.placeholder = placeholder
    this.dialogTarget.showModal()
    this.reasonTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }
}
