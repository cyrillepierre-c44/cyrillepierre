import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]
  static values  = {
    phrases:   Array,
    typeSpeed: { type: Number, default: 75 },
    delSpeed:  { type: Number, default: 38 },
    pause:     { type: Number, default: 2200 }
  }

  connect() {
    this.phraseIndex = 0
    this.charIndex   = 0
    this.deleting    = false
    this.timer       = null
    this.tick()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  tick() {
    const phrase = this.phrasesValue[this.phraseIndex]

    if (this.deleting) {
      this.textTarget.textContent = phrase.slice(0, this.charIndex - 1)
      this.charIndex--
    } else {
      this.textTarget.textContent = phrase.slice(0, this.charIndex + 1)
      this.charIndex++
    }

    if (!this.deleting && this.charIndex === phrase.length) {
      this.timer = setTimeout(() => { this.deleting = true; this.tick() }, this.pauseValue)
      return
    }

    if (this.deleting && this.charIndex === 0) {
      this.deleting    = false
      this.phraseIndex = (this.phraseIndex + 1) % this.phrasesValue.length
    }

    const speed = this.deleting ? this.delSpeedValue : this.typeSpeedValue
    this.timer  = setTimeout(() => this.tick(), speed)
  }
}
