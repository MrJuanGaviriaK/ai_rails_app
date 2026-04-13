import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["video", "canvas", "preview", "status", "signedIdInput", "captureButton"]
  static values = {
    directUploadUrl: String,
    i18n: Object
  }

  async connect() {
    this.stream = null
    this.capturedBlob = null
    await this.startCamera()
  }

  disconnect() {
    this.stopCamera()
  }

  async captureAndUpload(event) {
    event.preventDefault()

    if (!this.stream) {
      this.setStatus(this.t("cameraUnavailable", "Camera is unavailable."), true)
      return
    }

    this.captureButtonTarget.disabled = true
    this.setStatus(this.t("capturing", "Capturing photo..."))

    try {
      const blob = await this.captureBlob()
      this.capturedBlob = blob
      this.showPreview(blob)
      this.setStatus(this.t("uploading", "Uploading photo..."))
      await this.uploadBlob(blob)
      this.setStatus(this.t("uploaded", "Photo uploaded successfully."))
    } catch (_error) {
      this.setStatus(this.t("failed", "Could not capture or upload photo."), true)
      this.signedIdInputTarget.value = ""
    } finally {
      this.captureButtonTarget.disabled = false
    }
  }

  async startCamera() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" }, audio: false })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()
      this.setStatus(this.t("ready", "Camera ready."))
    } catch (_error) {
      this.setStatus(this.t("cameraUnavailable", "Could not access camera."), true)
    }
  }

  stopCamera() {
    this.stream?.getTracks()?.forEach((track) => track.stop())
    this.stream = null
  }

  captureBlob() {
    return new Promise((resolve, reject) => {
      const width = this.videoTarget.videoWidth || 640
      const height = this.videoTarget.videoHeight || 480

      this.canvasTarget.width = width
      this.canvasTarget.height = height

      const context = this.canvasTarget.getContext("2d")
      context.drawImage(this.videoTarget, 0, 0, width, height)

      this.canvasTarget.toBlob((blob) => {
        if (!blob) {
          reject(new Error("capture_failed"))
          return
        }

        resolve(blob)
      }, "image/jpeg", 0.9)
    })
  }

  uploadBlob(blob) {
    return new Promise((resolve, reject) => {
      const file = new File([blob], `miner-live-photo-${Date.now()}.jpg`, { type: "image/jpeg" })
      const upload = new DirectUpload(file, this.directUploadUrlValue)

      upload.create((error, uploadedBlob) => {
        if (error) {
          reject(error)
          return
        }

        this.signedIdInputTarget.value = uploadedBlob.signed_id
        resolve(uploadedBlob)
      })
    })
  }

  showPreview(blob) {
    const objectUrl = URL.createObjectURL(blob)
    this.previewTarget.src = objectUrl
    this.previewTarget.classList.remove("hidden")
  }

  setStatus(message, isError = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-red-300", isError)
    this.statusTarget.classList.toggle("text-emerald-300", !isError)
  }

  t(key, fallback) {
    return this.i18nValue?.[key] || fallback
  }
}
