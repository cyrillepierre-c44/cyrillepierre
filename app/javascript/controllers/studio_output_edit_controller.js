import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  edit() {
    this.displayTarget.classList.add("d-none")
    this.formTarget.classList.remove("d-none")
  }

  cancel() {
    this.formTarget.classList.add("d-none")
    this.displayTarget.classList.remove("d-none")
  }
}
