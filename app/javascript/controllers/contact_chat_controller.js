import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = [
    "themeCheckbox", "placeholder", "chatArea", "messages", "typing",
    "inputRow", "input", "sendBtn", "summaryBlock", "summaryText",
    "summaryField", "historyField", "submitBtn", "submitHint", "bottomSection",
    "summaryToast"
  ]

  static MAX_QUESTIONS = 3

  connect() {
    this.history = []
    this.chatStarted = false
    this.ready = false
    this.userMessageCount = 0
    this.prefetchPromise = null
    window.scrollTo({ top: 0, behavior: "instant" })
  }

  prefetchGreeting(event) {
    if (this.prefetchPromise || !event.target.value.trim()) return
    this.prefetchPromise = this.postToBackend("/contact/chat", {
      message: "", history: [], themes: [], initial: true
    })
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
    const data = await (this.prefetchPromise || this.postToBackend("/contact/chat", {
      message: "", history: [], themes: this.selectedThemes, initial: true
    }))
    this.hideTyping()
    const clean = this.stripReady(data.reply)
    this.appendMessage("assistant", clean)
    this.history.push({ role: "assistant", content: data.reply })
    this.setInputDisabled(false)
    if (!this.isMobile) this.inputTarget.focus({ preventScroll: true })
  }

  sendOnEnter(event) {
    if (event.key === "Enter") this.send()
  }

  async send() {
    const message = this.inputTarget.value.trim()
    if (!message || this.ready) return

    const voice = this.application.getControllerForElementAndIdentifier(this.inputRowTarget, "voice-input")
    if (voice) voice.stop()

    this.appendMessage("user", message)
    this.inputTarget.value = ""
    this.setInputDisabled(true)
    this.userMessageCount++
    this.history.push({ role: "user", content: message })
    this.historyFieldTarget.value = JSON.stringify(this.history)

    this.showTyping()
    const data = await this.postToBackend("/contact/chat", {
      message, history: this.history, themes: this.selectedThemes, initial: false
    })
    this.hideTyping()

    const isClarify = data.reply.includes("##CLARIFY##")
    if (isClarify) this.userMessageCount--

    const clean = this.stripReady(data.reply).replace("##CLARIFY##", "").trim()
    this.appendMessage("assistant", clean)
    this.history.push({ role: "assistant", content: data.reply })
    this.historyFieldTarget.value = JSON.stringify(this.history)

    const forceEnd = this.userMessageCount >= this.constructor.MAX_QUESTIONS
    if (data.ready || forceEnd) {
      this.ready = true
      this.setInputDisabled(true)
      if (!data.ready) {
        this.appendMessage("assistant", "Merci, j'ai tout ce qu'il me faut. Je prépare votre résumé…")
      }
      await this.generateSummary()
    } else {
      this.setInputDisabled(false)
      if (!this.isMobile) this.inputTarget.focus({ preventScroll: true })
    }
  }

  async generateSummary() {
    this.showTyping()
    const data = await this.postToBackend("/contact/summarize", {
      history: this.history, themes: this.selectedThemes
    })
    this.hideTyping()

    this.summaryTextTarget.innerHTML = marked.parse(data.summary || "")
    this.summaryFieldTarget.value = data.summary
    this.historyFieldTarget.value = JSON.stringify(this.history)

    this.summaryBlockTarget.classList.remove("d-none")
    this.inputRowTarget.classList.add("d-none")
    this.bottomSectionTarget.classList.remove("d-none")
    this.submitBtnTarget.disabled = false
    this.submitHintTarget.classList.add("d-none")

    this.summaryToastTarget.classList.remove("d-none")
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

  scrollToSummary() {
    this.summaryToastTarget.classList.add("d-none")
    this.scrollToElement(this.summaryBlockTarget)
  }

  scrollToElement(el) {
    const NAVBAR = 72
    const MARGIN = 16
    const top = el.getBoundingClientRect().top + window.scrollY - NAVBAR - MARGIN
    window.scrollTo({ top, behavior: "smooth" })
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

  get isMobile() {
    return window.matchMedia("(hover: none) and (pointer: coarse)").matches
  }

  get selectedThemes() {
    return this.themeCheckboxTargets
      .filter(cb => cb.querySelector("input")?.checked)
      .map(cb => cb.querySelector("input").value)
  }
}
