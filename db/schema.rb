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

ActiveRecord::Schema[8.1].define(version: 2026_08_13_151000) do
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

  create_table "admin_audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.text "metadata"
    t.integer "resource_id"
    t.string "resource_type"
    t.integer "target_user_id"
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["admin_user_id"], name: "index_admin_audit_logs_on_admin_user_id"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
    t.index ["target_user_id"], name: "index_admin_audit_logs_on_target_user_id"
  end

  create_table "body_metrics", force: :cascade do |t|
    t.decimal "chest_cm", precision: 5, scale: 1
    t.datetime "created_at", null: false
    t.decimal "hips_cm", precision: 5, scale: 1
    t.decimal "left_arm_cm", precision: 5, scale: 1
    t.decimal "left_leg_cm", precision: 5, scale: 1
    t.datetime "measured_at", null: false
    t.text "notes"
    t.decimal "right_arm_cm", precision: 5, scale: 1
    t.decimal "right_leg_cm", precision: 5, scale: 1
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.decimal "waist_cm", precision: 5, scale: 1
    t.decimal "weight_kg", precision: 5, scale: 2
    t.index ["user_id", "measured_at"], name: "index_body_metrics_on_user_id_and_measured_at"
    t.index ["user_id"], name: "index_body_metrics_on_user_id"
  end

  create_table "exercise_sets", force: :cascade do |t|
    t.decimal "band_tension_kg"
    t.boolean "belt", default: false, null: false
    t.decimal "chain_weight_kg"
    t.string "client_request_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.decimal "distance_meters"
    t.integer "duration_seconds"
    t.boolean "is_amrap", default: false
    t.boolean "is_bfr", default: false, null: false
    t.boolean "is_failed", default: false, null: false
    t.boolean "is_warmup"
    t.boolean "knee_sleeves", default: false, null: false
    t.boolean "pain_flag", default: false, null: false
    t.string "pain_note"
    t.integer "partial_reps"
    t.integer "position"
    t.integer "reps"
    t.integer "rir"
    t.decimal "rpe"
    t.string "set_type", default: "normal"
    t.boolean "spotter_assisted", default: false, null: false
    t.boolean "straps", default: false, null: false
    t.integer "tempo_concentric"
    t.integer "tempo_eccentric"
    t.integer "tempo_pause_bottom"
    t.integer "tempo_pause_top"
    t.datetime "updated_at", null: false
    t.decimal "weight_kg"
    t.integer "workout_exercise_id", null: false
    t.boolean "wrist_wraps", default: false, null: false
    t.index ["client_request_id"], name: "index_exercise_sets_on_client_request_id", unique: true
    t.index ["workout_exercise_id"], name: "index_exercise_sets_on_workout_exercise_id"
  end

  create_table "exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "exercise_type"
    t.text "form_cues"
    t.boolean "has_weight"
    t.string "name"
    t.string "primary_muscle_group"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_exercises_on_user_id"
  end

  create_table "gyms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name"
    t.text "notes"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_gyms_on_user_id"
  end

  create_table "machines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_unit"
    t.string "equipment_type"
    t.integer "gym_id", null: false
    t.string "handle_setting"
    t.string "name"
    t.text "notes"
    t.string "pin_setting"
    t.datetime "retired_at"
    t.string "seat_setting"
    t.datetime "updated_at", null: false
    t.decimal "weight_ratio"
    t.index ["gym_id"], name: "index_machines_on_gym_id"
    t.index ["retired_at"], name: "index_machines_on_retired_at"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dedupe_key", null: false
    t.string "kind", null: false
    t.text "message", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "read_at"
    t.string "severity", default: "info", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "dedupe_key"], name: "index_notifications_on_user_id_and_dedupe_key", unique: true
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "program_cycles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ended_on"
    t.date "starts_on", null: false
    t.string "status", default: "active", null: false
    t.integer "training_program_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["training_program_id", "status"], name: "index_program_cycles_on_training_program_id_and_status"
    t.index ["training_program_id"], name: "index_program_cycles_on_training_program_id"
    t.index ["user_id"], name: "index_program_cycles_on_one_active_user", unique: true, where: "status = 'active'"
    t.index ["user_id"], name: "index_program_cycles_on_user_id"
  end

  create_table "program_session_executions", force: :cascade do |t|
    t.text "adjustment_notes"
    t.string "adjustment_reason"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "intensity_percent", default: 100, null: false
    t.integer "prescribed_sets", default: 0, null: false
    t.decimal "prescribed_volume_kg", precision: 12, scale: 3, default: "0.0", null: false
    t.json "prescription", default: [], null: false
    t.integer "program_cycle_id", null: false
    t.integer "program_session_id", null: false
    t.date "scheduled_on", null: false
    t.string "session_name", null: false
    t.text "skip_notes"
    t.string "skip_reason"
    t.string "status", default: "planned", null: false
    t.datetime "updated_at", null: false
    t.integer "volume_percent", default: 100, null: false
    t.string "workout_template_name", null: false
    t.index ["program_cycle_id", "program_session_id"], name: "index_program_executions_on_cycle_and_session", unique: true
    t.index ["program_cycle_id", "scheduled_on"], name: "idx_on_program_cycle_id_scheduled_on_de2e8040e9"
    t.index ["program_cycle_id"], name: "index_program_session_executions_on_program_cycle_id"
    t.index ["program_session_id"], name: "index_program_session_executions_on_program_session_id"
  end

  create_table "program_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "intensity_percent", default: 100, null: false
    t.string "name"
    t.text "notes"
    t.integer "position", default: 1, null: false
    t.integer "training_program_id", null: false
    t.datetime "updated_at", null: false
    t.integer "volume_percent", default: 100, null: false
    t.integer "week_number", null: false
    t.integer "weekday", null: false
    t.integer "workout_template_id", null: false
    t.index ["training_program_id", "week_number", "weekday", "position"], name: "index_program_sessions_on_schedule", unique: true
    t.index ["training_program_id"], name: "index_program_sessions_on_training_program_id"
    t.index ["workout_template_id"], name: "index_program_sessions_on_workout_template_id"
  end

  create_table "progress_photos", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "notes"
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "category"], name: "index_progress_photos_on_user_id_and_category"
    t.index ["user_id", "taken_at"], name: "index_progress_photos_on_user_id_and_taken_at"
    t.index ["user_id"], name: "index_progress_photos_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.datetime "expiration_time"
    t.datetime "last_successful_push_at"
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["last_successful_push_at"], name: "index_push_subscriptions_on_last_successful_push_at"
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "template_blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "rest_seconds", default: 90
    t.datetime "updated_at", null: false
    t.integer "workout_template_id", null: false
    t.index ["workout_template_id", "position"], name: "index_template_blocks_on_workout_template_id_and_position"
    t.index ["workout_template_id"], name: "index_template_blocks_on_workout_template_id"
  end

  create_table "template_exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "exercise_id", null: false
    t.integer "machine_id"
    t.text "persistent_notes"
    t.integer "target_reps"
    t.integer "target_sets"
    t.decimal "target_weight_kg", precision: 8, scale: 2
    t.integer "template_block_id", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_template_exercises_on_exercise_id"
    t.index ["machine_id"], name: "index_template_exercises_on_machine_id"
    t.index ["template_block_id", "exercise_id"], name: "index_template_exercises_on_template_block_id_and_exercise_id"
    t.index ["template_block_id"], name: "index_template_exercises_on_template_block_id"
  end

  create_table "training_programs", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "weeks_count", default: 4, null: false
    t.index ["user_id", "archived_at"], name: "index_training_programs_on_user_id_and_archived_at"
    t.index ["user_id"], name: "index_training_programs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.integer "default_gym_id"
    t.integer "default_rest_seconds", default: 90
    t.string "email_address", null: false
    t.string "name"
    t.boolean "notify_plateau", default: true, null: false
    t.boolean "notify_readiness", default: true, null: false
    t.boolean "notify_rest_timer_in_app", default: true, null: false
    t.boolean "notify_rest_timer_push", default: true, null: false
    t.boolean "notify_streak_risk", default: true, null: false
    t.boolean "notify_volume_drop", default: true, null: false
    t.string "password_digest", null: false
    t.string "preferred_unit"
    t.integer "progression_rep_target", default: 10, null: false
    t.datetime "updated_at", null: false
    t.boolean "weekly_summary_email", default: false, null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["default_gym_id"], name: "index_users_on_default_gym_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["updated_at"], name: "index_users_on_updated_at"
  end

  create_table "workout_blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.integer "rest_seconds"
    t.datetime "updated_at", null: false
    t.integer "workout_id", null: false
    t.index ["workout_id"], name: "index_workout_blocks_on_workout_id"
  end

  create_table "workout_exercises", force: :cascade do |t|
    t.string "bar_type"
    t.datetime "created_at", null: false
    t.integer "exercise_id", null: false
    t.string "grip_width"
    t.integer "incline_angle"
    t.integer "machine_id"
    t.text "persistent_notes"
    t.integer "position"
    t.text "session_notes"
    t.string "stance"
    t.integer "template_exercise_id"
    t.datetime "updated_at", null: false
    t.integer "workout_block_id", null: false
    t.index ["exercise_id"], name: "index_workout_exercises_on_exercise_id"
    t.index ["machine_id"], name: "index_workout_exercises_on_machine_id"
    t.index ["template_exercise_id"], name: "index_workout_exercises_on_template_exercise_id"
    t.index ["workout_block_id"], name: "index_workout_exercises_on_workout_block_id"
  end

  create_table "workout_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.boolean "pinned", default: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_workout_templates_on_user_id"
  end

  create_table "workouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "gym_id", null: false
    t.text "notes"
    t.integer "program_session_execution_id"
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_workouts_on_created_at"
    t.index ["gym_id"], name: "index_workouts_on_gym_id"
    t.index ["program_session_execution_id"], name: "index_workouts_on_program_session_execution_id", unique: true
    t.index ["user_id", "finished_at"], name: "index_workouts_on_user_id_and_finished_at"
    t.index ["user_id"], name: "index_workouts_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_audit_logs", "users", column: "admin_user_id"
  add_foreign_key "admin_audit_logs", "users", column: "target_user_id"
  add_foreign_key "body_metrics", "users"
  add_foreign_key "exercise_sets", "workout_exercises"
  add_foreign_key "exercises", "users"
  add_foreign_key "gyms", "users"
  add_foreign_key "machines", "gyms"
  add_foreign_key "notifications", "users"
  add_foreign_key "program_cycles", "training_programs"
  add_foreign_key "program_cycles", "users"
  add_foreign_key "program_session_executions", "program_cycles"
  add_foreign_key "program_session_executions", "program_sessions"
  add_foreign_key "program_sessions", "training_programs"
  add_foreign_key "program_sessions", "workout_templates"
  add_foreign_key "progress_photos", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "template_blocks", "workout_templates"
  add_foreign_key "template_exercises", "exercises"
  add_foreign_key "template_exercises", "machines"
  add_foreign_key "template_exercises", "template_blocks"
  add_foreign_key "training_programs", "users"
  add_foreign_key "users", "gyms", column: "default_gym_id"
  add_foreign_key "workout_blocks", "workouts"
  add_foreign_key "workout_exercises", "exercises"
  add_foreign_key "workout_exercises", "machines"
  add_foreign_key "workout_exercises", "template_exercises"
  add_foreign_key "workout_exercises", "workout_blocks"
  add_foreign_key "workout_templates", "users"
  add_foreign_key "workouts", "gyms"
  add_foreign_key "workouts", "program_session_executions"
  add_foreign_key "workouts", "users"
end
