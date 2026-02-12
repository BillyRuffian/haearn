class AddAdminAndDeactivatedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :deactivated_at, :datetime
    add_index :users, :admin
  end
end
