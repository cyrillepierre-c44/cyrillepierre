import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "btn", "counter"]
  static values  = {
    maxLength: { type: Number, default: 500 },
    lang:      { type: String, default: "fr-FR" }
  }

  connect() {
    this.recognition = null
    this.listening   = false
    this.baseText    = ""
    this.addedFinal  = ""

    this.updateCounter()
    this.fieldTarget.addEventListener("input", () => this.updateCounter())

    const supported = "SpeechRecognition" in window || "webkitSpeechRecognition" in window
    if (!supported) this.btnTarget.hidden = true
  }

  toggle() {
    this.listening ? this.stop() : this.start()
  }

  start() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition    = new SR()
    this.recognition.lang            = this.langValue
    this.recognition.continuous      = true
    this.recognition.interimResults  = true

    this.baseText   = this.fieldTarget.value
    this.addedFinal = ""

    this.recognition.onresult = (event) => {
      let interim = ""
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          this.addedFinal += event.results[i][0].transcript + " "
        } else {
          interim = event.results[i][0].transcript
        }
      }
      const full = (this.baseText + this.addedFinal + interim).trimEnd()
      this.fieldTarget.value = full.slice(0, this.maxLengthValue)
      this.updateCounter()
    }

    this.recognition.onend = () => {
      this.baseText   = this.fieldTarget.value
      this.addedFinal = ""
      if (this.listening) this.recognition.start()
    }

    this.recognition.onerror = (event) => {
      if (event.error !== "aborted") this.stop()
    }

    this.recognition.start()
    this.listening = true
    this.btnTarget.classList.add("voice-btn--active")
    this.btnTarget.title = "Arrêter l'écoute"
  }

  stop() {
    this.listening = false
    if (this.recognition) this.recognition.stop()
    this.btnTarget.classList.remove("voice-btn--active")
    this.btnTarget.title = "Dicter ma réponse"
  }

  updateCounter() {
    const len = this.fieldTarget.value.length
    const max = this.maxLengthValue
    this.counterTarget.textContent = `${len} / ${max}`
    this.counterTarget.classList.toggle("voice-counter--warn", len > max * 0.85)
    this.counterTarget.classList.toggle("voice-counter--over", len >= max)
  }

  disconnect() {
    this.stop()
  }
}
