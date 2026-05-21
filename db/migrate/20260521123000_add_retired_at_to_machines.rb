class AddRetiredAtToMachines < ActiveRecord::Migration[8.0]
  def change
    add_column :machines, :retired_at, :datetime
    add_index :machines, :retired_at
  end
end
