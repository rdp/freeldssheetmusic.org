class DownloadCount < ActiveRecord::Migration

  def self.up
    add_column :user_uploads, :count, :int, :default => 1
  end

  def self.down
    remove_column :user_uploads, :count
  end
  
end
