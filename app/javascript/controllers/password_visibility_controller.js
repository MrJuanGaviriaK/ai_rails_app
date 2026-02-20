import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "eyeIcon", "eyeOffIcon"]

  connect() {
    this.hidden = true
  }

  toggle() {
    this.hidden = !this.hidden
    this.inputTarget.type = this.hidden ? "password" : "text"
    this.eyeIconTarget.classList.toggle("hidden", !this.hidden)
    this.eyeOffIconTarget.classList.toggle("hidden", this.hidden)
  }
}
