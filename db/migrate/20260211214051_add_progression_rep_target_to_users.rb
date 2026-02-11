class AddProgressionRepTargetToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :progression_rep_target, :integer, default: 10, null: false
  end
end
