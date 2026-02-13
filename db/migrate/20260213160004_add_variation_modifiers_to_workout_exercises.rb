class AddVariationModifiersToWorkoutExercises < ActiveRecord::Migration[8.0]
  def change
    # Exercise variation modifiers - stored on workout_exercise, not exercise
    add_column :workout_exercises, :grip_width, :string
    add_column :workout_exercises, :stance, :string
    add_column :workout_exercises, :incline_angle, :integer
    add_column :workout_exercises, :bar_type, :string
  end
end
