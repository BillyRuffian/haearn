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

ActiveRecord::Schema[8.1].define(version: 2026_02_04_130225) do
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

  create_table "exercise_sets", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.decimal "distance_meters"
    t.integer "duration_seconds"
    t.boolean "is_warmup"
    t.integer "position"
    t.integer "reps"
    t.datetime "updated_at", null: false
    t.decimal "weight_kg"
    t.integer "workout_exercise_id", null: false
    t.index ["workout_exercise_id"], name: "index_exercise_sets_on_workout_exercise_id"
  end

  create_table "exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "exercise_type"
    t.boolean "has_weight"
    t.string "name"
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
    t.string "name"
    t.text "notes"
    t.datetime "updated_at", null: false
    t.decimal "weight_ratio"
    t.index ["gym_id"], name: "index_machines_on_gym_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_gym_id"
    t.integer "default_rest_seconds", default: 90
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "preferred_unit"
    t.datetime "updated_at", null: false
    t.index ["default_gym_id"], name: "index_users_on_default_gym_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
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
    t.datetime "created_at", null: false
    t.integer "exercise_id", null: false
    t.integer "machine_id", null: false
    t.text "persistent_notes"
    t.integer "position"
    t.text "session_notes"
    t.datetime "updated_at", null: false
    t.integer "workout_block_id", null: false
    t.index ["exercise_id"], name: "index_workout_exercises_on_exercise_id"
    t.index ["machine_id"], name: "index_workout_exercises_on_machine_id"
    t.index ["workout_block_id"], name: "index_workout_exercises_on_workout_block_id"
  end

  create_table "workouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "gym_id", null: false
    t.text "notes"
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["gym_id"], name: "index_workouts_on_gym_id"
    t.index ["user_id"], name: "index_workouts_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "exercise_sets", "workout_exercises"
  add_foreign_key "exercises", "users"
  add_foreign_key "gyms", "users"
  add_foreign_key "machines", "gyms"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "gyms", column: "default_gym_id"
  add_foreign_key "workout_blocks", "workouts"
  add_foreign_key "workout_exercises", "exercises"
  add_foreign_key "workout_exercises", "machines"
  add_foreign_key "workout_exercises", "workout_blocks"
  add_foreign_key "workouts", "gyms"
  add_foreign_key "workouts", "users"
end
