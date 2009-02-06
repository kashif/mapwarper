# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090202223821) do

  create_table "audits", :force => true do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "changes"
    t.integer  "version",        :default => 0
    t.datetime "created_at"
  end

  add_index "audits", ["auditable_id", "auditable_type"], :name => "auditable_index"
  add_index "audits", ["created_at"], :name => "index_audits_on_created_at"
  add_index "audits", ["user_id", "user_type"], :name => "user_index"

  create_table "gcps", :force => true do |t|
    t.integer  "map_id"
    t.float    "x"
    t.float    "y"
    t.decimal  "lat",        :precision => 15, :scale => 10
    t.decimal  "lon",        :precision => 15, :scale => 10
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "maps", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.string   "filename"
    t.integer  "width"
    t.integer  "height"
    t.integer  "status"
    t.integer  "mask_status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "upload_file_name"
    t.string   "upload_content_type"
    t.integer  "upload_file_size"
    t.datetime "upload_file_updated_at"
    t.string   "bbox"
    t.string   "publisher"
    t.string   "authors"
    t.string   "scale"
    t.datetime "published_date"
    t.datetime "reprint_date"
    t.integer  "owner_id"
    t.boolean  "public",                 :default => true
  end

  create_table "my_maps", :force => true do |t|
    t.integer  "map_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "my_maps", ["map_id", "user_id"], :name => "index_my_maps_on_map_id_and_user_id", :unique => true
  add_index "my_maps", ["map_id"], :name => "index_my_maps_on_map_id"

  create_table "permissions", :force => true do |t|
    t.integer  "role_id",    :null => false
    t.integer  "user_id",    :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles", :force => true do |t|
    t.string   "name"
    t.integer  "updated_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "email"
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token"
    t.datetime "remember_token_expires_at"
    t.string   "activation_code",           :limit => 40
    t.datetime "activated_at"
    t.string   "password_reset_code",       :limit => 40
    t.boolean  "enabled",                                 :default => true
    t.integer  "updated_by"
  end

end
