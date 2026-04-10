import { Controller } from "@hotwired/stimulus"

const HELLOSIGN_EMBEDDED_SDK_URL = "https://cdn.jsdelivr.net/npm/hellosign-embedded@2.12.3/umd/embedded.production.min.js"
const HELLOSIGN_EMBEDDED_SDK_SCRIPT_ID = "hellosign-embedded-sdk"

export default class extends Controller {
  static targets = ["container", "status"]
  static values = {
    signUrl: String,
    clientId: String,
    completeUrl: String,
    i18n: Object
  }

  async connect() {
    this.ensureContainerHeight()
    this.observeEmbeddedLayout()

    const sdkLoaded = await this.ensureHelloSignSdkLoaded()
    if (!sdkLoaded) {
      this.statusTarget.textContent = this.t("failed", "Dropbox Sign signer failed to load. Please try again.")
      return
    }

    this.client = new window.HelloSign()
    this.registerEvents()
    this.open()
  }

  disconnect() {
    this.layoutObserver?.disconnect()
    this.layoutObserver = null
  }

  async open(event) {
    event?.preventDefault()

    if (!this.signUrlValue || !this.clientIdValue) {
      this.statusTarget.textContent = this.t("failed", "Missing embedded signing configuration.")
      return
    }

    this.statusTarget.textContent = this.t("opening", "Opening embedded signing...")

    this.client.open(this.signUrlValue, {
      clientId: this.clientIdValue,
      container: this.containerTarget,
      allowCancel: true,
      skipDomainVerification: true
    })

    this.ensureEmbeddedFullHeight()
  }

  registerEvents() {
    this.client.on("open", () => {
      this.statusTarget.textContent = this.t("opened", "Embedded signing opened.")
      this.ensureEmbeddedFullHeight()
    })

    this.client.on("finish", () => {
      this.statusTarget.textContent = this.t("finished", "Signature completed. Processing evidence...")
      this.completeAndRedirect()
    })

    this.client.on("close", () => {
      this.statusTarget.textContent = this.t("closed", "Embedded signing closed.")
    })

    this.client.on("error", () => {
      this.statusTarget.textContent = this.t("failed", "Dropbox Sign signer failed to load. Please try again.")
    })
  }

  async completeAndRedirect() {
    if (!this.completeUrlValue) return

    try {
      const response = await fetch(this.completeUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "text/html"
        }
      })

      window.location.assign(response.url)
    } catch (_error) {
      this.statusTarget.textContent = this.t("failed", "Could not finalize signature. Please use the complete button.")
    }
  }

  async ensureHelloSignSdkLoaded() {
    if (window.HelloSign) return true

    if (!window.__helloSignEmbeddedSdkPromise) {
      window.__helloSignEmbeddedSdkPromise = new Promise((resolve) => {
        let script = document.getElementById(HELLOSIGN_EMBEDDED_SDK_SCRIPT_ID)

        if (!script) {
          script = document.createElement("script")
          script.id = HELLOSIGN_EMBEDDED_SDK_SCRIPT_ID
          script.src = HELLOSIGN_EMBEDDED_SDK_URL
          script.async = true
          script.defer = true
          document.head.appendChild(script)
        }

        script.addEventListener("load", () => resolve(Boolean(window.HelloSign)), { once: true })
        script.addEventListener("error", () => resolve(false), { once: true })
      })
    }

    return window.__helloSignEmbeddedSdkPromise
  }

  ensureContainerHeight() {
    const availableHeight = Math.max(window.innerHeight - 220, 620)
    this.containerTarget.style.height = `${availableHeight}px`
  }

  observeEmbeddedLayout() {
    this.layoutObserver = new MutationObserver(() => {
      this.ensureEmbeddedFullHeight()
    })

    this.layoutObserver.observe(this.containerTarget, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["style", "class"]
    })
  }

  ensureEmbeddedFullHeight() {
    const iframe = this.containerTarget.querySelector("iframe")
    if (!iframe) return

    iframe.style.setProperty("height", "100%", "important")
    iframe.style.setProperty("min-height", "100%", "important")
    iframe.style.setProperty("width", "100%", "important")

    let node = iframe.parentElement
    while (node && node !== this.containerTarget) {
      node.style.setProperty("height", "100%", "important")
      node.style.setProperty("min-height", "100%", "important")
      node = node.parentElement
    }
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  t(key, fallback) {
    return this.i18nValue?.[key] || fallback
  }
}
