import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "themeCheckbox", "placeholder", "chatArea", "messages", "typing",
    "inputRow", "input", "sendBtn", "summaryBlock", "summaryText",
    "summaryField", "historyField", "submitBtn", "submitHint"
  ]

  connect() {
    this.history = []
    this.chatStarted = false
    this.ready = false
  }

  themeChanged() {
    if (this.hasAnyThemeSelected() && !this.chatStarted) {
      this.chatStarted = true
      this.placeholderTarget.classList.add("d-none")
      this.chatAreaTarget.classList.remove("d-none")
      this.triggerInitialGreeting()
    }
  }

  async triggerInitialGreeting() {
    this.setInputDisabled(true)
    this.showTyping()
    const data = await this.postToBackend("/contact/chat", {
      message: "", history: [], themes: this.selectedThemes, initial: true
    })
    this.hideTyping()
    const clean = this.stripReady(data.reply)
    this.appendMessage("assistant", clean)
    this.history.push({ role: "assistant", content: data.reply })
    this.setInputDisabled(false)
    this.inputTarget.focus()
  }

  sendOnEnter(event) {
    if (event.key === "Enter") this.send()
  }

  async send() {
    const message = this.inputTarget.value.trim()
    if (!message || this.ready) return

    this.appendMessage("user", message)
    this.inputTarget.value = ""
    this.setInputDisabled(true)
    this.history.push({ role: "user", content: message })
    this.historyFieldTarget.value = JSON.stringify(this.history)

    this.showTyping()
    const data = await this.postToBackend("/contact/chat", {
      message, history: this.history, themes: this.selectedThemes, initial: false
    })
    this.hideTyping()

    const clean = this.stripReady(data.reply)
    this.appendMessage("assistant", clean)
    this.history.push({ role: "assistant", content: data.reply })
    this.historyFieldTarget.value = JSON.stringify(this.history)

    if (data.ready) {
      this.ready = true
      this.setInputDisabled(true)
      this.appendMessage("assistant", "Parfait, je prépare le résumé de votre demande…")
      await this.generateSummary()
    } else {
      this.setInputDisabled(false)
      this.inputTarget.focus()
    }
  }

  async generateSummary() {
    this.showTyping()
    const data = await this.postToBackend("/contact/summarize", {
      history: this.history, themes: this.selectedThemes
    })
    this.hideTyping()

    this.summaryTextTarget.innerText = data.summary
    this.summaryFieldTarget.value = data.summary
    this.historyFieldTarget.value = JSON.stringify(this.history)

    this.summaryBlockTarget.classList.remove("d-none")
    this.inputRowTarget.classList.add("d-none")
    this.submitBtnTarget.disabled = false
    this.submitHintTarget.classList.add("d-none")
  }

  async postToBackend(url, body) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify(body)
      })
      return await response.json()
    } catch {
      return { reply: "Je rencontre une difficulté. Écrivez à cyrille.pierre@gmail.com", ready: false, summary: "" }
    }
  }

  appendMessage(role, content) {
    const div = document.createElement("div")
    div.className = `chat-msg chat-msg--${role}`
    div.innerText = content
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  showTyping() { this.typingTarget.classList.remove("d-none") }
  hideTyping() { this.typingTarget.classList.add("d-none") }

  setInputDisabled(disabled) {
    this.inputTarget.disabled = disabled
    this.sendBtnTarget.disabled = disabled
  }

  stripReady(text) {
    return (text || "").replace("##READY##", "").trim()
  }

  hasAnyThemeSelected() {
    return this.themeCheckboxTargets.some(cb => cb.querySelector("input")?.checked)
  }

  get selectedThemes() {
    return this.themeCheckboxTargets
      .filter(cb => cb.querySelector("input")?.checked)
      .map(cb => cb.querySelector("input").value)
  }
}
