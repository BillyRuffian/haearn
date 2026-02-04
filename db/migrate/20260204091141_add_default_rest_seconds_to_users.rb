class AddDefaultRestSecondsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_rest_seconds, :integer, default: 90
  end
end
