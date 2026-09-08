# frozen_string_literal: true

class AddRemovedAtToTemplateExercises < ActiveRecord::Migration[8.1]
  def change
    add_column :template_exercises, :removed_at, :datetime
    add_index :template_exercises, [ :template_block_id, :removed_at ]
  end
end
