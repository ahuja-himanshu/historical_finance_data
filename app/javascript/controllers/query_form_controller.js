import { Controller } from "@hotwired/stimulus"

// Lightweight form UX: auto-submit on control change and toggle month field.
export default class extends Controller {
  static targets = ["mode", "monthField"]

  connect() {
    this.toggleMonth()
  }

  submit() {
    // Small delay feels smoother when chaining select changes
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      this.element.requestSubmit()
    }, 40)
  }

  toggleMonth() {
    if (!this.hasModeTarget || !this.hasMonthFieldTarget) return
    const isMonth = this.modeTarget.value === "month"
    this.monthFieldTarget.style.display = isMonth ? "" : "none"
  }
}
