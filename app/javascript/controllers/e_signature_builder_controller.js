import { Controller } from "@hotwired/stimulus"

const HELLOSIGN_EMBEDDED_SDK_URL = "https://cdn.jsdelivr.net/npm/hellosign-embedded@2.12.3/umd/embedded.production.min.js"
const HELLOSIGN_EMBEDDED_SDK_SCRIPT_ID = "hellosign-embedded-sdk"

export default class extends Controller {
  static targets = ["container", "status"]
  static values = {
    clientId: String,
    editUrl: String,
    skipDomainVerification: Boolean,
    completeUrl: String,
    i18n: Object
  }

  async connect() {
    this.pendingCompletionRedirect = false
    this.ensureContainerHeight()
    this.observeEmbeddedLayout()

    const sdkLoaded = await this.ensureHelloSignSdkLoaded()
    if (!sdkLoaded) {
      this.statusTarget.textContent = this.t("failed", "Dropbox Sign editor failed to load. Please try reopening it.")
      return
    }

    this.client = new window.HelloSign()
    this.registerEvents()
    this.open()
  }

  async open(event) {
    event?.preventDefault()

    if (!this.client) {
      const sdkLoaded = await this.ensureHelloSignSdkLoaded()
      if (!sdkLoaded) {
        this.statusTarget.textContent = this.t("failed", "Dropbox Sign editor failed to load. Please try reopening it.")
        return
      }

      this.client = new window.HelloSign()
      this.registerEvents()
    }

    this.statusTarget.textContent = this.t("opening", "Opening Dropbox Sign editor...")

    this.client.open(this.editUrlValue, {
      clientId: this.clientIdValue,
      container: this.containerTarget,
      skipDomainVerification: this.skipDomainVerificationValue,
      allowCancel: true
    })

    this.ensureEmbeddedFullHeight()
  }

  registerEvents() {
    this.client.on("open", () => {
      this.statusTarget.textContent = this.t("opened", "Dropbox Sign editor opened.")
      this.ensureEmbeddedFullHeight()
    })

    this.client.on("finish", () => {
      this.statusTarget.textContent = this.t("finished", "Template updates were saved in Dropbox Sign.")
      this.pendingCompletionRedirect = true

      try {
        this.client.close()
      } catch (_error) {
        this.redirectAfterCompletion()
      }

      setTimeout(() => {
        this.redirectAfterCompletion()
      }, 500)
    })

    this.client.on("close", () => {
      this.statusTarget.textContent = this.t("closed", "Editor closed. You can reopen it anytime.")
      this.redirectAfterCompletion()
    })

    this.client.on("error", () => {
      this.statusTarget.textContent = this.t("failed", "Dropbox Sign editor failed to load. Please try reopening it.")
    })
  }

  disconnect() {
    this.layoutObserver?.disconnect()
    this.layoutObserver = null
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

  t(key, fallback) {
    return this.i18nValue?.[key] || fallback
  }

  redirectAfterCompletion() {
    if (!this.pendingCompletionRedirect || !this.completeUrlValue) return

    this.pendingCompletionRedirect = false
    window.location.replace(this.completeUrlValue)
  }
}
