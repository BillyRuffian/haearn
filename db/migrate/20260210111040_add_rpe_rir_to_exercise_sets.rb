class AddRpeRirToExerciseSets < ActiveRecord::Migration[8.1]
  def change
    add_column :exercise_sets, :rpe, :decimal
    add_column :exercise_sets, :rir, :integer
  end
end
