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

ActiveRecord::Schema[7.1].define(version: 2026_08_29_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.date "appointment_date"
    t.time "appointment_time"
    t.string "status"
    t.text "notes"
    t.bigint "doctor_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "clinic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "clinic", null: false
    t.string "patient_email"
    t.index ["clinic_id"], name: "index_appointments_on_clinic_id"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
  end

  create_table "billing_settings", force: :cascade do |t|
    t.integer "singleton_guard", default: 0, null: false
    t.integer "price_per_visit_cents", default: 200, null: false
    t.string "currency", default: "EUR", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_guard"], name: "index_billing_settings_on_singleton_guard", unique: true
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content", default: "", null: false
    t.jsonb "response_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_chat_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["role"], name: "index_chat_messages_on_role"
  end

  create_table "clinics", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "phone"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plan"
    t.datetime "trial_ends_at"
    t.boolean "subscribed"
    t.string "billing_customer_id"
    t.string "billing_subscription_id"
    t.string "plan_tier", default: "starter", null: false
    t.string "slug", null: false
    t.integer "price_per_visit_cents"
    t.index ["slug"], name: "index_clinics_on_slug", unique: true
    t.index ["user_id"], name: "index_clinics_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id", "created_at"], name: "index_conversations_on_clinic_id_and_created_at"
    t.index ["clinic_id"], name: "index_conversations_on_clinic_id"
  end

  create_table "doctors", force: :cascade do |t|
    t.string "name"
    t.string "specialty"
    t.string "phone"
    t.time "work_start"
    t.time "work_end"
    t.bigint "clinic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_doctors_on_clinic_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.integer "age"
    t.string "gender"
    t.text "notes"
    t.bigint "clinic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.index ["clinic_id"], name: "index_patients_on_clinic_id"
  end

  create_table "prescription_items", force: :cascade do |t|
    t.bigint "prescription_id", null: false
    t.string "medicine_name"
    t.string "dosage"
    t.string "frequency"
    t.string "duration"
    t.text "instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prescription_id"], name: "index_prescription_items_on_prescription_id"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.date "prescription_date"
    t.text "diagnosis"
    t.text "notes"
    t.bigint "clinic_id", null: false
    t.bigint "doctor_id", null: false
    t.bigint "patient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_prescriptions_on_clinic_id"
    t.index ["doctor_id"], name: "index_prescriptions_on_doctor_id"
    t.index ["patient_id"], name: "index_prescriptions_on_patient_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.string "lemon_subscription_id", null: false
    t.string "lemon_customer_id"
    t.string "lemon_order_id"
    t.string "lemon_product_id"
    t.string "lemon_variant_id"
    t.string "status", default: "active", null: false
    t.string "plan_tier", default: "starter", null: false
    t.datetime "renews_at"
    t.datetime "ends_at"
    t.datetime "trial_ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_subscriptions_on_clinic_id"
    t.index ["lemon_customer_id"], name: "index_subscriptions_on_lemon_customer_id"
    t.index ["lemon_subscription_id"], name: "index_subscriptions_on_lemon_subscription_id", unique: true
    t.index ["status"], name: "index_subscriptions_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "super_admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "visits", force: :cascade do |t|
    t.bigint "clinic_id", null: false
    t.bigint "appointment_id"
    t.bigint "patient_id"
    t.bigint "doctor_id"
    t.date "occurred_on", null: false
    t.string "source", default: "appointment", null: false
    t.integer "price_cents", default: 0, null: false
    t.string "currency", default: "EUR", null: false
    t.datetime "voided_at"
    t.datetime "invoiced_at"
    t.string "invoice_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_visits_on_appointment_id", unique: true
    t.index ["clinic_id", "occurred_on"], name: "index_visits_on_clinic_id_and_occurred_on"
    t.index ["clinic_id", "voided_at"], name: "index_visits_on_clinic_id_and_voided_at"
    t.index ["clinic_id"], name: "index_visits_on_clinic_id"
    t.index ["doctor_id"], name: "index_visits_on_doctor_id"
    t.index ["patient_id"], name: "index_visits_on_patient_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "clinics"
  add_foreign_key "appointments", "doctors"
  add_foreign_key "appointments", "patients"
  add_foreign_key "chat_messages", "conversations"
  add_foreign_key "clinics", "users"
  add_foreign_key "conversations", "clinics"
  add_foreign_key "doctors", "clinics"
  add_foreign_key "patients", "clinics"
  add_foreign_key "prescription_items", "prescriptions"
  add_foreign_key "prescriptions", "clinics"
  add_foreign_key "prescriptions", "doctors"
  add_foreign_key "prescriptions", "patients"
  add_foreign_key "subscriptions", "clinics"
  add_foreign_key "visits", "appointments", on_delete: :nullify
  add_foreign_key "visits", "clinics"
  add_foreign_key "visits", "doctors", on_delete: :nullify
  add_foreign_key "visits", "patients", on_delete: :nullify
end
