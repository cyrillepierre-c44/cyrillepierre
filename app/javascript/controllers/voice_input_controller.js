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
    this.restartTimer = null

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
    this.recognition = new SR()
    this.recognition.lang           = this.langValue
    this.recognition.continuous     = false  // plus fiable sur Android
    this.recognition.interimResults = true

    this.baseText = this.fieldTarget.value

    this.recognition.onresult = (event) => {
      // On ne lit que le dernier résultat — évite les doublons Android
      const result     = event.results[event.results.length - 1]
      const transcript = result[0].transcript
      const sep        = this.baseText.length > 0 && !this.baseText.endsWith(" ") ? " " : ""

      if (result.isFinal) {
        this.baseText = (this.baseText + sep + transcript).slice(0, this.maxLengthValue)
        this.fieldTarget.value = this.baseText
      } else {
        this.fieldTarget.value = (this.baseText + sep + transcript).slice(0, this.maxLengthValue)
      }
      this.updateCounter()
    }

    this.recognition.onend = () => {
      // Délai court pour éviter le double-trigger Android
      if (this.listening) {
        this.restartTimer = setTimeout(() => {
          if (this.listening) this.recognition.start()
        }, 120)
      }
    }

    this.recognition.onerror = (event) => {
      // "no-speech" et "aborted" sont normaux — on ne coupe pas le micro
      if (event.error !== "aborted" && event.error !== "no-speech") this.stop()
    }

    this.recognition.start()
    this.listening = true
    this.btnTarget.classList.add("voice-btn--active")
    this.btnTarget.title = "Arrêter l'écoute"
  }

  stop() {
    this.listening = false
    clearTimeout(this.restartTimer)
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
