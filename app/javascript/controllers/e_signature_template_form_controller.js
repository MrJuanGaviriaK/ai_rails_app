import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rolesContainer", "roleTemplate", "roleNumber", "mergeFieldsContainer", "mergeFieldTemplate"]

  connect() {
    this.ensureAtLeastOneRole()
    this.renumberRoles()
  }

  addRole(event) {
    event.preventDefault()
    this.insertRow(this.rolesContainerTarget, this.roleTemplateTarget)
    this.renumberRoles()
  }

  removeRole(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-role-row]")?.remove()
    this.ensureAtLeastOneRole()
    this.renumberRoles()
  }

  addMergeField(event) {
    event.preventDefault()
    this.insertRow(this.mergeFieldsContainerTarget, this.mergeFieldTemplateTarget)
  }

  removeMergeField(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-merge-field-row]")?.remove()
  }

  insertRow(container, template) {
    const index = this.nextIndex(container)
    container.insertAdjacentHTML("beforeend", template.innerHTML.replaceAll("__INDEX__", String(index)))
  }

  nextIndex(container) {
    const current = parseInt(container.dataset.nextIndex || "0", 10)
    container.dataset.nextIndex = String(current + 1)
    return current
  }

  ensureAtLeastOneRole() {
    if (this.rolesContainerTarget.querySelectorAll("[data-role-row]").length > 0) return

    this.insertRow(this.rolesContainerTarget, this.roleTemplateTarget)
  }

  renumberRoles() {
    this.roleNumberTargets.forEach((target, index) => {
      target.textContent = String(index + 1)
    })
  }
}
