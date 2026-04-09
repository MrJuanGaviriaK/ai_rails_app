import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "toast", "list", "empty", "modal", "modalTitle", "editId", "name", "apiKey", "clientId", "priority", "testMode",
    "saveButton", "testButton", "saveStatus"
  ]

  static values = { tenant: String, i18n: Object }

  connect() {
    this.integrations = []
    this.refresh()
  }

  get integrationsUrl() {
    return `/api/v1/integrations?tenant=${this.tenantValue}`
  }

  async refresh() {
    try {
      const res = await fetch(this.integrationsUrl)
      const data = await res.json()
      this.integrations = data.integrations || []
      this.renderIntegrations()
    } catch (_error) {
      this.showToast(this.t("messages.load_failed", "Failed to load integrations"), "error")
    }
  }

  renderIntegrations() {
    if (this.integrations.length === 0) {
      this.listTarget.innerHTML = ""
      this.emptyTarget.classList.remove("hidden")
      return
    }

    this.emptyTarget.classList.add("hidden")
    this.listTarget.innerHTML = this.integrations.map((integration) => {
      const statusClass = integration.status === "active" ? "text-emerald-300" : integration.status === "error" ? "text-red-300" : "text-gray-300"
      const toggleStatus = integration.status === "active" ? "inactive" : "active"
      const toggleLabel = integration.status === "active" ? this.t("actions.deactivate", "Deactivate") : this.t("actions.activate", "Activate")

      return `
        <div class="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-semibold text-white">${this.escapeHtml(integration.name)}</p>
            <p class="text-xs text-gray-400">Dropbox Sign · ${this.t("labels.provider_priority", "Priority")} ${integration.priority}</p>
            <p class="text-xs ${statusClass}">${this.t("labels.status", "Status")}: ${integration.status}</p>
            ${integration.last_error_message ? `<p class="text-xs text-red-300">${this.escapeHtml(integration.last_error_message)}</p>` : ""}
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <a href="/admin/e_signature_templates?integration_id=${integration.id}" class="rounded-md border border-[#34588f] bg-[#0a1628] px-3 py-1.5 text-xs font-semibold text-gray-200 transition hover:bg-[#102447]">${this.t("actions.templates", "Templates")}</a>
            <button data-action="click->integrations-admin#toggleStatus" data-integration-id="${integration.id}" data-next-status="${toggleStatus}" class="rounded-md border border-[#34588f] bg-[#0a1628] px-3 py-1.5 text-xs font-semibold text-gray-200 transition hover:bg-[#102447]">${toggleLabel}</button>
            <button data-action="click->integrations-admin#edit" data-integration-id="${integration.id}" class="rounded-md border border-[#34588f] bg-[#0a1628] px-3 py-1.5 text-xs font-semibold text-gray-200 transition hover:bg-[#102447]">${this.t("actions.edit", "Edit")}</button>
            <button data-action="click->integrations-admin#delete" data-integration-id="${integration.id}" class="rounded-md border border-red-400/35 bg-red-500/10 px-3 py-1.5 text-xs font-semibold text-red-200 transition hover:bg-red-500/20">${this.t("actions.delete", "Delete")}</button>
          </div>
        </div>
      `
    }).join("")
  }

  showAddForm() {
    this.editIdTarget.value = ""
    this.modalTitleTarget.textContent = this.t("modal.add_title", "Add Dropbox Sign Integration")
    this.nameTarget.value = ""
    this.apiKeyTarget.value = ""
    this.clientIdTarget.value = ""
    this.priorityTarget.value = "0"
    this.testModeTarget.checked = false
    this.saveStatusTarget.textContent = ""
    this.modalTarget.classList.remove("hidden")
  }

  hideModal() {
    this.modalTarget.classList.add("hidden")
  }

  edit(event) {
    const id = parseInt(event.currentTarget.dataset.integrationId, 10)
    const integration = this.integrations.find((item) => item.id === id)
    if (!integration) return

    this.editIdTarget.value = String(integration.id)
    this.modalTitleTarget.textContent = `${this.t("modal.edit_prefix", "Edit")} ${integration.name}`
    this.nameTarget.value = integration.name
    this.apiKeyTarget.value = ""
    this.clientIdTarget.value = ""
    this.priorityTarget.value = integration.priority ?? 0
    this.testModeTarget.checked = integration.settings?.test_mode === true
    this.saveStatusTarget.textContent = integration.has_credentials ? this.t("messages.credentials_saved", "Credentials are stored. Leave blank to keep.") : ""
    this.modalTarget.classList.remove("hidden")
  }

  async saveIntegration() {
    const id = this.editIdTarget.value
    const isEdit = id.length > 0
    const payload = {
      integration: {
        provider: "dropbox_sign",
        name: this.nameTarget.value.trim(),
        priority: parseInt(this.priorityTarget.value, 10) || 0,
        settings: {
          test_mode: this.testModeTarget.checked
        }
      }
    }

    const credentials = {}
    if (this.apiKeyTarget.value.trim()) credentials.api_key = this.apiKeyTarget.value.trim()
    if (this.clientIdTarget.value.trim()) credentials.client_id = this.clientIdTarget.value.trim()
    if (Object.keys(credentials).length > 0) payload.integration.credentials = credentials

    this.saveButtonTarget.disabled = true
    this.saveStatusTarget.textContent = this.t("messages.saving", "Saving...")

    try {
      const url = isEdit ? `/api/v1/integrations/${id}?tenant=${this.tenantValue}` : this.integrationsUrl
      const res = await fetch(url, {
        method: isEdit ? "PATCH" : "POST",
        headers: this.jsonHeaders(),
        credentials: "same-origin",
        body: JSON.stringify(payload)
      })

      const data = await res.json()
      if (res.ok) {
        this.hideModal()
        this.showToast(isEdit ? this.t("messages.integration_updated", "Integration updated") : this.t("messages.integration_created", "Integration created"), "success")
        await this.refresh()
      } else {
        this.saveStatusTarget.textContent = (data.error || []).join?.(", ") || data.error || this.t("messages.save_failed", "Save failed")
      }
    } catch (_error) {
      this.saveStatusTarget.textContent = this.t("messages.network_error", "Network error")
    } finally {
      this.saveButtonTarget.disabled = false
    }
  }

  async testConnection() {
    const id = this.editIdTarget.value
    if (!id) {
      this.saveStatusTarget.textContent = this.t("messages.save_integration_first", "Save integration first before testing")
      return
    }

    this.testButtonTarget.disabled = true
    this.saveStatusTarget.textContent = this.t("messages.testing_connection", "Testing connection...")

    try {
      const res = await fetch(`/api/v1/integrations/${id}/test_connection?tenant=${this.tenantValue}`, {
        method: "POST",
        headers: this.csrfHeader(),
        credentials: "same-origin"
      })
      const data = await res.json()
      if (res.ok && data.success) {
        this.saveStatusTarget.textContent = `${this.t("messages.connected_prefix", "Connected")}: ${data.account_name || data.account_id || this.t("common.ok", "OK")}`
        await this.refresh()
      } else {
        this.saveStatusTarget.textContent = `${this.t("messages.failed_prefix", "Failed")}: ${data.error || this.t("common.unknown_error", "Unknown error")}`
      }
    } catch (_error) {
      this.saveStatusTarget.textContent = this.t("messages.connection_failed", "Connection test failed")
    } finally {
      this.testButtonTarget.disabled = false
    }
  }

  async toggleStatus(event) {
    const id = event.currentTarget.dataset.integrationId
    const nextStatus = event.currentTarget.dataset.nextStatus

    try {
      const res = await fetch(`/api/v1/integrations/${id}?tenant=${this.tenantValue}`, {
        method: "PATCH",
        headers: this.jsonHeaders(),
        credentials: "same-origin",
        body: JSON.stringify({ integration: { status: nextStatus } })
      })

      if (res.ok) {
        this.showToast(this.t("messages.update_success", "Integration updated"), "success")
        await this.refresh()
      } else {
        this.showToast(this.t("messages.update_failed", "Failed to update status"), "error")
      }
    } catch (_error) {
      this.showToast(this.t("messages.network_error", "Network error"), "error")
    }
  }

  async delete(event) {
    const id = event.currentTarget.dataset.integrationId
    if (!confirm(this.t("messages.confirm_delete", "Delete this integration and all associated templates?"))) return

    try {
      const res = await fetch(`/api/v1/integrations/${id}?tenant=${this.tenantValue}`, {
        method: "DELETE",
        headers: this.csrfHeader(),
        credentials: "same-origin"
      })
      if (res.ok) {
        this.showToast(this.t("messages.delete_success", "Integration deleted"), "success")
        await this.refresh()
      } else {
        this.showToast(this.t("messages.delete_failed", "Failed to delete integration"), "error")
      }
    } catch (_error) {
      this.showToast(this.t("messages.network_error", "Network error"), "error")
    }
  }

  t(path, fallback) {
    const value = path.split(".").reduce((acc, key) => (acc && acc[key] !== undefined ? acc[key] : undefined), this.i18nValue || {})
    return value ?? fallback
  }

  csrfHeader() {
    const token = this.csrfToken()
    return token ? { "X-CSRF-Token": token } : {}
  }

  jsonHeaders() {
    return {
      "Content-Type": "application/json",
      ...this.csrfHeader()
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  showToast(message, type = "info") {
    const toast = this.toastTarget
    toast.textContent = message
    toast.className = `rounded-xl border px-4 py-3 text-sm ${type === "success" ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300" : type === "error" ? "border-red-500/30 bg-red-500/10 text-red-300" : "border-slate-700 bg-slate-800 text-slate-300"}`
    toast.classList.remove("hidden")

    setTimeout(() => {
      toast.classList.add("hidden")
    }, 3500)
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str || ""
    return div.innerHTML
  }
}
