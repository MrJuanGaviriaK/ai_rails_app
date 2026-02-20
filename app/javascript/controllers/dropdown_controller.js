import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._boundHide = this.hide.bind(this)
    this._boundKeydown = this.keydown.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.menuTarget.classList.contains("hidden")

    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this._boundHide)
    document.addEventListener("keydown", this._boundKeydown)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this._boundHide)
    document.removeEventListener("keydown", this._boundKeydown)
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    this.close()
  }
}
