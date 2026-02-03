class CreateWorkoutExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_exercises do |t|
      t.references :workout_block, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.references :machine, null: false, foreign_key: true
      t.integer :position
      t.text :session_notes
      t.text :persistent_notes

      t.timestamps
    end
  end
end
