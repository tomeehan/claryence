import { Controller } from "@hotwired/stimulus"

// Toggles spinner/label on form submit using Turbo events.
// Usage: add data-controller="submit-loading" on the submit <button>.
export default class extends Controller {
  static targets = ["label", "spinner"]

  connect() {
    this.start = this.start.bind(this)
    this.end = this.end.bind(this)
    this.onSubmit = this.onSubmit.bind(this)

    // Listen on nearest form only
    this.form = this.element.closest("form")
    if (this.form) {
      // Fire immediately for non‑Turbo (local) submits
      this.form.addEventListener("submit", this.onSubmit)
      // Also handle Turbo lifecycle when enabled
      this.form.addEventListener("turbo:submit-start", this.start)
      this.form.addEventListener("turbo:submit-end", this.end)
    }
    this.end() // ensure initial state
  }

  disconnect() {
    if (this.form) {
      this.form.removeEventListener("submit", this.onSubmit)
      this.form.removeEventListener("turbo:submit-start", this.start)
      this.form.removeEventListener("turbo:submit-end", this.end)
    }
  }

  onSubmit() { this.start() }

  start() {
    this.toggle(true)
  }

  end() {
    this.toggle(false)
  }

  toggle(loading) {
    if (this.hasSpinnerTarget) this.spinnerTarget.style.display = loading ? "inline-flex" : "none"
    if (this.hasLabelTarget) this.labelTarget.style.display = loading ? "none" : "inline-flex"
    this.element.toggleAttribute("disabled", loading)
  }
}
