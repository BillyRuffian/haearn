class AddSetupMemoryFieldsToMachines < ActiveRecord::Migration[8.1]
  def change
    add_column :machines, :seat_setting, :string
    add_column :machines, :pin_setting, :string
    add_column :machines, :handle_setting, :string
  end
end
