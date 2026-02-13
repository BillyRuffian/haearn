class AddAdminMetricsIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :created_at
    add_index :users, :updated_at
    add_index :workouts, :created_at
  end
end
