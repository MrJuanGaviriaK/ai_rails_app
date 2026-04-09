import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "buyerSection", "location"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isBuyer = this.roleTarget.value === "buyer"
    this.buyerSectionTarget.classList.toggle("hidden", !isBuyer)

    if (!isBuyer) {
      this.locationTarget.value = ""
    }
  }
}
