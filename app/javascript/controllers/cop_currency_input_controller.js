import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "hidden"]

  connect() {
    const initialRawValue = this.hiddenTarget.value || ""
    this.displayTarget.value = initialRawValue ? this.formatFromRaw(initialRawValue) : ""
  }

  onInput() {
    const parsed = this.parseDisplay(this.displayTarget.value)

    this.hiddenTarget.value = parsed.raw
    this.displayTarget.value = parsed.formatted
  }

  formatFromRaw(rawValue) {
    const normalized = rawValue.toString().replace(/[^\d,\.]/g, "").replace(/,/g, ".")
    const number = Number.parseFloat(normalized)
    if (Number.isNaN(number)) return ""

    return this.formatNumber(number)
  }

  parseDisplay(value) {
    const cleaned = value.toString().replace(/[^\d,]/g, "")
    if (cleaned.length === 0) return { raw: "", formatted: "" }

    const segments = cleaned.split(",")
    const integerPart = segments[0].replace(/^0+(?=\d)/, "") || "0"
    const decimalPart = (segments[1] || "").slice(0, 2)

    const raw = decimalPart.length > 0 ? `${integerPart}.${decimalPart}` : integerPart
    const numericValue = Number.parseFloat(raw)

    if (Number.isNaN(numericValue)) return { raw: "", formatted: "" }

    const formatted = this.formatNumber(numericValue, decimalPart.length)
    return { raw, formatted }
  }

  formatNumber(number, forceDecimals = null) {
    const hasDecimals = forceDecimals !== null ? forceDecimals > 0 : !Number.isInteger(number)
    const [integerDigits, decimalDigits] = number.toFixed(hasDecimals ? 2 : 0).split(".")

    const integerWithSeparators = integerDigits.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    const colombianStyleInteger = integerWithSeparators.replace(/^(\d+)\.(\d{3}\.\d{3}(?:\.\d{3})*)$/, "$1'$2")

    return hasDecimals ? `$${colombianStyleInteger},${decimalDigits}` : `$${colombianStyleInteger}`
  }
}
