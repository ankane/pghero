ActiveRecord::Migration.verbose = ENV["VERBOSE"]

ActiveRecord::Migration.enable_extension "pg_stat_statements"
ActiveRecord::Migration.enable_extension "ltree"

ActiveRecord::Migration.create_table :pghero_query_stats, force: true do |t|
  t.text :database
  t.text :user
  t.text :query
  t.integer :query_hash, limit: 8
  t.float :total_time
  t.integer :calls, limit: 8
  t.timestamp :captured_at
  t.index [:database, :captured_at]
end

ActiveRecord::Migration.create_table :pghero_space_stats, force: true do |t|
  t.text :database
  t.text :schema
  t.text :relation
  t.integer :size, limit: 8
  t.timestamp :captured_at
  t.index [:database, :captured_at]
end

ActiveRecord::Migration.create_table :cities, force: true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :states, force: true do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :users, force: true do |t|
  t.integer :city_id
  t.integer :login_attempts
  t.string :email
  t.string :zip_code
  t.boolean :active
  t.string :country
  t.column :path, :ltree
  t.column :range, :int4range
  t.column :description, :text
  t.column :ts_description, :tsvector
  t.column :last_known_ip, :inet
  t.column :metadata, :jsonb
  t.timestamp :created_at
  t.timestamp :updated_at
  t.index :id # duplicate index
  t.index :updated_at
  t.index "country gist_trgm_ops", using: :gist
  t.index :zip_code, using: :hash
  t.index :path, using: :gist
  t.index :range, using: :gist
  t.index :ts_description, using: :gist
  t.index 'last_known_ip inet_ops', using: :gist
  t.index :created_at, using: :brin
  t.index :metadata, using: :gin
end
