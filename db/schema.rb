# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_10_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "buyer_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "purchasing_location_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_by_id"], name: "index_buyer_profiles_on_created_by_id"
    t.index ["purchasing_location_id"], name: "index_buyer_profiles_on_purchasing_location_id"
    t.index ["user_id"], name: "index_buyer_profiles_on_user_id", unique: true
  end

  create_table "e_signature_requests", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "e_signature_template_id", null: false
    t.datetime "failed_at"
    t.text "failure_reason"
    t.bigint "initiated_by_id"
    t.bigint "integration_id", null: false
    t.string "provider", null: false
    t.string "provider_signature_id"
    t.string "provider_signature_request_id"
    t.jsonb "raw_provider_payload", default: {}, null: false
    t.bigint "requestable_id", null: false
    t.string "requestable_type", default: "Seller", null: false
    t.datetime "sent_at"
    t.datetime "signed_at"
    t.string "signed_ip"
    t.string "status", default: "draft", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["e_signature_template_id"], name: "index_e_signature_requests_on_e_signature_template_id"
    t.index ["initiated_by_id"], name: "index_e_signature_requests_on_initiated_by_id"
    t.index ["integration_id"], name: "index_e_signature_requests_on_integration_id"
    t.index ["provider", "provider_signature_request_id"], name: "idx_e_signature_requests_provider_request"
    t.index ["requestable_id"], name: "index_e_signature_requests_on_requestable_id"
    t.index ["requestable_type", "requestable_id", "status"], name: "idx_e_signature_requests_requestable_status"
    t.index ["tenant_id", "status"], name: "idx_e_signature_requests_tenant_status"
    t.index ["tenant_id"], name: "index_e_signature_requests_on_tenant_id"
  end

  create_table "e_signature_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: [], null: false
    t.bigint "integration_id", null: false
    t.datetime "last_synced_at"
    t.text "message"
    t.jsonb "metadata", default: {}, null: false
    t.string "provider_template_id", null: false
    t.jsonb "signer_roles", default: [], null: false
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id", "provider_template_id"], name: "idx_esig_templates_integration_provider", unique: true
    t.index ["integration_id"], name: "index_e_signature_templates_on_integration_id"
    t.index ["tenant_id", "active"], name: "index_e_signature_templates_on_tenant_id_and_active"
    t.index ["tenant_id"], name: "index_e_signature_templates_on_tenant_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.string "capabilities", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: {}, null: false
    t.datetime "last_connected_at"
    t.string "last_error_message"
    t.string "name", null: false
    t.integer "priority", default: 0, null: false
    t.string "provider", null: false
    t.jsonb "provider_config", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.string "status", default: "inactive", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_integrations_on_capabilities", using: :gin
    t.index ["status"], name: "index_integrations_on_status"
    t.index ["tenant_id", "provider"], name: "index_integrations_on_tenant_id_and_provider"
    t.index ["tenant_id"], name: "index_integrations_on_tenant_id"
  end

  create_table "purchasing_locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address", null: false
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "department", null: false
    t.string "name", null: false
    t.text "notes"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_purchasing_locations_on_deleted_at"
    t.index ["tenant_id", "deleted_at"], name: "index_purchasing_locations_on_tenant_id_and_deleted_at"
    t.index ["tenant_id", "department"], name: "index_purchasing_locations_on_tenant_id_and_department"
    t.index ["tenant_id"], name: "index_purchasing_locations_on_tenant_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "seller_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "seller_id", null: false
    t.string "status", default: "uploaded", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id"
    t.index ["seller_id", "kind"], name: "idx_seller_documents_seller_kind"
    t.index ["seller_id"], name: "index_seller_documents_on_seller_id"
    t.index ["uploaded_by_id"], name: "index_seller_documents_on_uploaded_by_id"
  end

  create_table "sellers", force: :cascade do |t|
    t.string "address", null: false
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "department", null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "identification_number", null: false
    t.string "identification_type", null: false
    t.string "last_name", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "phone"
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "seller_type", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_sellers_on_created_by_id"
    t.index ["reviewed_by_id"], name: "index_sellers_on_reviewed_by_id"
    t.index ["tenant_id", "identification_type", "identification_number"], name: "idx_sellers_tenant_identification_unique", unique: true
    t.index ["tenant_id", "status"], name: "idx_sellers_tenant_status"
    t.index ["tenant_id"], name: "index_sellers_on_tenant_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name"
    t.bigint "reviewed_by_id"
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_tenants_on_deleted_at"
    t.index ["reviewed_by_id"], name: "index_tenants_on_reviewed_by_id"
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["status"], name: "index_tenants_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "buyer_profiles", "purchasing_locations", on_delete: :restrict
  add_foreign_key "buyer_profiles", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "buyer_profiles", "users", on_delete: :cascade
  add_foreign_key "e_signature_requests", "e_signature_templates"
  add_foreign_key "e_signature_requests", "integrations"
  add_foreign_key "e_signature_requests", "sellers", column: "requestable_id", on_delete: :cascade
  add_foreign_key "e_signature_requests", "tenants"
  add_foreign_key "e_signature_requests", "users", column: "initiated_by_id"
  add_foreign_key "e_signature_templates", "integrations"
  add_foreign_key "e_signature_templates", "tenants"
  add_foreign_key "integrations", "tenants"
  add_foreign_key "purchasing_locations", "tenants"
  add_foreign_key "seller_documents", "sellers", on_delete: :cascade
  add_foreign_key "seller_documents", "users", column: "uploaded_by_id"
  add_foreign_key "sellers", "tenants"
  add_foreign_key "sellers", "users", column: "created_by_id"
  add_foreign_key "sellers", "users", column: "reviewed_by_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tenants", "users", column: "reviewed_by_id"
  add_foreign_key "users_roles", "roles"
  add_foreign_key "users_roles", "users"
end
