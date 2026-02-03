class AddDefaultGymToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :default_gym, foreign_key: { to_table: :gyms }, null: true
  end
end
