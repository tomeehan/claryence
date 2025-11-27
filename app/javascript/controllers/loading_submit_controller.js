import { Controller } from "@hotwired/stimulus"

// Usage: add data-controller="loading-submit" on a <form>
// On submit, disables the submit button and shows a spinner + label.
export default class extends Controller {
  static values = {
    label: { type: String, default: "Starting…" }
  }

  connect() {
    this._onSubmit = this._onSubmit.bind(this)
    this.element.addEventListener("submit", this._onSubmit)
  }

  disconnect() {
    this.element.removeEventListener("submit", this._onSubmit)
  }

  _onSubmit(event) {
    const btn = this.element.querySelector('[type="submit"]')
    if (!btn || btn.dataset.loading === "true") return

    btn.dataset.loading = "true"
    btn.dataset.originalHtml = btn.innerHTML
    btn.disabled = true

    btn.innerHTML = `
      <span class="inline-flex items-center justify-center gap-2">
        <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
        </svg>
        <span>${this.labelValue}</span>
      </span>
    `
  }
}

