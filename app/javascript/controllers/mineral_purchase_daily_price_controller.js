import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mineralType", "fineGrams", "totalDisplay", "totalHidden", "alert", "alertMessage", "submitButton"]
  static values = {
    url: String,
    errorMessage: String
  }

  connect() {
    this.requestCounter = 0
    this.unitPriceCop = null
    this.checkAvailability()
  }

  onMineralTypeChange() {
    this.unitPriceCop = null
    this.recalculateTotalAndSubmitState()
    this.checkAvailability()
  }

  onFineGramsChange() {
    this.recalculateTotalAndSubmitState()
  }

  async checkAvailability() {
    const mineralType = this.selectedMineralType

    if (!mineralType) {
      this.hideAlert()
      this.unitPriceCop = null
      this.recalculateTotalAndSubmitState()
      return
    }

    const requestId = ++this.requestCounter
    this.setSubmitDisabled(true)

    try {
      const response = await fetch(`${this.urlValue}?mineral_type=${encodeURIComponent(mineralType)}`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error("daily price availability request failed")

      const payload = await response.json()
      if (requestId !== this.requestCounter) return

      if (payload.available) {
        this.unitPriceCop = this.parseNumber(payload.unit_price_cop)
        this.hideAlert()
      } else {
        this.unitPriceCop = null
        this.showAlert(payload.message || this.errorMessageValue)
      }

      this.recalculateTotalAndSubmitState()
    } catch (_error) {
      if (requestId !== this.requestCounter) return

      this.hideAlert()
      this.unitPriceCop = null
      this.recalculateTotalAndSubmitState()
    }
  }

  get selectedMineralType() {
    return this.hasMineralTypeTarget ? this.mineralTypeTarget.value.trim() : ""
  }

  get selectedFineGrams() {
    return this.hasFineGramsTarget ? this.parseNumber(this.fineGramsTarget.value) : null
  }

  recalculateTotalAndSubmitState() {
    const fineGrams = this.selectedFineGrams

    if (this.canCalculateTotal(fineGrams)) {
      const calculatedTotal = this.roundHalfUp(this.unitPriceCop * fineGrams)
      this.totalHiddenTarget.value = calculatedTotal.toFixed(2)
      this.totalDisplayTarget.value = this.formatCop(calculatedTotal)
      this.setSubmitDisabled(false)
      return
    }

    this.totalHiddenTarget.value = ""
    this.totalDisplayTarget.value = ""
    this.setSubmitDisabled(true)
  }

  canCalculateTotal(fineGrams) {
    return this.unitPriceCop !== null && fineGrams !== null && fineGrams > 0
  }

  parseNumber(value) {
    if (value === null || value === undefined) return null

    const raw = value.toString().trim()
    if (raw.length === 0) return null

    const hasComma = raw.includes(",")
    const hasDot = raw.includes(".")

    let normalized = raw

    if (hasComma && hasDot) {
      normalized = raw.replace(/\./g, "").replace(",", ".")
    } else if (hasComma) {
      normalized = raw.replace(",", ".")
    }

    normalized = normalized.replace(/[^\d.-]/g, "")
    if (normalized.length === 0) return null

    const parsed = Number.parseFloat(normalized)
    return Number.isNaN(parsed) ? null : parsed
  }

  roundHalfUp(value) {
    return Math.round((value + Number.EPSILON) * 100) / 100
  }

  formatCop(value) {
    return new Intl.NumberFormat("es-CO", {
      style: "currency",
      currency: "COP",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value)
  }

  showAlert(message) {
    if (!this.hasAlertTarget) return

    if (this.hasAlertMessageTarget) {
      this.alertMessageTarget.textContent = message
    }

    this.alertTarget.classList.remove("hidden")
  }

  hideAlert() {
    if (!this.hasAlertTarget) return

    this.alertTarget.classList.add("hidden")
  }

  setSubmitDisabled(disabled) {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = disabled
  }
}
