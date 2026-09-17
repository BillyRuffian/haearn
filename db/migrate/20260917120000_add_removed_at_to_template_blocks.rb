class AddRemovedAtToTemplateBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :template_blocks, :removed_at, :datetime
    add_index :template_blocks, [ :workout_template_id, :removed_at ]
  end
end
