class CreateExerciseSets < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_sets do |t|
      t.references :workout_exercise, null: false, foreign_key: true
      t.integer :position
      t.boolean :is_warmup
      t.decimal :weight_kg
      t.integer :reps
      t.integer :duration_seconds
      t.decimal :distance_meters
      t.datetime :completed_at

      t.timestamps
    end
  end
end
