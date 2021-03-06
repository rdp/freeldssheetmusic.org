# run this with script/runner...with a specified environment...
class CreateCache < ActiveRecord::Migration
  def self.up
    raise 'need sqlite3' if Cache.connection.class.to_s =~ /mysql/i

    create_table :cache do |t|
      #t.column <sigh> 
    end
    add_column :cache, :hash_key, :bigint
    add_column :cache, :marshalled_value, :longtext, :default => nil
    add_column :cache, :string_value, :longtext, :default => nil
    add_index  :cache, :hash_key
    add_column :cache, :parent_id, :bigint # 054
    add_column :cache, :cache_type, :string # 057
  end
 
  def self.down
    drop_table :cache
  end
end
loc = SQLITE3_LOCATION
p 'creating...' + loc
raise unless loc.present?
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => loc)
CreateCache.up
