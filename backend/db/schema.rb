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

ActiveRecord::Schema[7.1].define(version: 2026_08_16_102237) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "queue_entries", force: :cascade do |t|
    t.integer "group_size", null: false
    t.string "phone_number", null: false
    t.string "status", default: "waiting", null: false
    t.string "active_visit_token", null: false
    t.string "idempotency_key", null: false
    t.string "seating_code"
    t.datetime "joined_at", null: false
    t.datetime "ready_at"
    t.datetime "seated_at"
    t.datetime "left_at"
    t.datetime "no_show_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_visit_token"], name: "index_queue_entries_on_active_visit_token", unique: true
    t.index ["idempotency_key"], name: "index_queue_entries_on_idempotency_key", unique: true
    t.index ["seating_code"], name: "index_queue_entries_on_seating_code", unique: true, where: "(seating_code IS NOT NULL)"
    t.index ["status", "joined_at"], name: "index_queue_entries_on_status_and_joined_at"
    t.check_constraint "group_size > 0", name: "queue_entries_group_size_positive"
    t.check_constraint "status::text = ANY (ARRAY['waiting'::character varying, 'ready'::character varying, 'seated'::character varying, 'left'::character varying, 'no_show'::character varying]::text[])", name: "queue_entries_status_valid"
  end

  create_table "seating_assignment_tables", force: :cascade do |t|
    t.bigint "seating_assignment_id", null: false
    t.bigint "table_id", null: false
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seating_assignment_id"], name: "index_seating_assignment_tables_on_seating_assignment_id"
    t.index ["table_id"], name: "index_seating_assignment_tables_on_claimed_table", unique: true, where: "(released_at IS NULL)"
    t.index ["table_id"], name: "index_seating_assignment_tables_on_table_id"
  end

  create_table "seating_assignments", force: :cascade do |t|
    t.bigint "queue_entry_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at"
    t.datetime "activated_at"
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["queue_entry_id"], name: "index_seating_assignments_on_current_queue_entry", unique: true, where: "((status)::text <> 'released'::text)"
    t.index ["queue_entry_id"], name: "index_seating_assignments_on_queue_entry_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'active'::character varying, 'released'::character varying]::text[])", name: "seating_assignments_status_valid"
  end

  create_table "staff_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_staff_users_on_email", unique: true
  end

  create_table "table_adjacencies", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.bigint "adjacent_table_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["adjacent_table_id"], name: "index_table_adjacencies_on_adjacent_table_id"
    t.index ["table_id", "adjacent_table_id"], name: "index_table_adjacencies_on_pair", unique: true
    t.index ["table_id"], name: "index_table_adjacencies_on_table_id"
    t.check_constraint "table_id < adjacent_table_id", name: "table_adjacencies_canonical_order"
  end

  create_table "tables", force: :cascade do |t|
    t.string "name", null: false
    t.integer "capacity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tables_on_name", unique: true
    t.check_constraint "capacity > 0", name: "tables_capacity_positive"
  end

  add_foreign_key "seating_assignment_tables", "seating_assignments"
  add_foreign_key "seating_assignment_tables", "tables"
  add_foreign_key "seating_assignments", "queue_entries"
  add_foreign_key "table_adjacencies", "tables"
  add_foreign_key "table_adjacencies", "tables", column: "adjacent_table_id"
end
