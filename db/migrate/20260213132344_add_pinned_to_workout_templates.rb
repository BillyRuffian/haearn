class AddPinnedToWorkoutTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :workout_templates, :pinned, :boolean, default: false
  end
end
