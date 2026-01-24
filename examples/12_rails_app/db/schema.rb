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

ActiveRecord::Schema[8.1].define(version: 2025_01_24_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instructions"
    t.string "model_id"
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.string "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "models", force: :cascade do |t|
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.decimal "input_price_per_million", precision: 10, scale: 4
    t.integer "max_tokens"
    t.jsonb "metadata", default: {}
    t.string "model_id", null: false
    t.string "name"
    t.decimal "output_price_per_million", precision: 10, scale: 4
    t.string "provider"
    t.boolean "supports_functions", default: false
    t.boolean "supports_vision", default: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_models_on_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id"
  end

  add_foreign_key "messages", "chats"
  add_foreign_key "tool_calls", "messages"
end
