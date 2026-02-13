class AddIsAmrapToExerciseSets < ActiveRecord::Migration[8.1]
  def change
    add_column :exercise_sets, :is_amrap, :boolean, default: false
  end
end
