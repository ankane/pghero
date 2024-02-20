ActiveRecord::Schema.define do
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "ltree"

  create_table :pghero_query_stats, force: true do |t|
    t.text :database
    t.text :user
    t.text :query
    t.integer :query_hash, limit: 8
    t.float :total_time
    t.integer :calls, limit: 8
    t.timestamp :captured_at
    t.index [:database, :captured_at]
  end

  create_table :pghero_space_stats, force: true do |t|
    t.text :database
    t.text :schema
    t.text :relation
    t.integer :size, limit: 8
    t.timestamp :captured_at
    t.index [:database, :captured_at]
  end

  create_table :cities, force: true do |t|
    t.string :name
  end

  create_table :states, force: true do |t|
    t.string :name
  end

  create_table :users, force: :cascade do |t|
    t.integer :city_id
    t.integer :login_attempts
    t.string :email
    t.string :zip_code
    t.boolean :active
    t.string :country
    t.column :tree_path, :ltree
    t.column :range, :int4range
    t.column :last_known_ip, :inet
    t.column :metadata, :jsonb
    t.timestamp :created_at
    t.timestamp :updated_at
    t.index :id # duplicate index
    t.index :updated_at
    t.index :login_attempts, using: :hash
    t.index "country gist_trgm_ops", using: :gist
    t.index :tree_path, using: :gist
    t.index :range, using: :gist
    t.index :created_at, using: :brin
    t.index "last_known_ip inet_ops", using: :gist
    t.index :metadata, using: :gin
  end
end
