class CreateTemplateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :template_exercises do |t|
      t.references :template_block, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.references :machine, null: true, foreign_key: true
      t.text :persistent_notes
      t.integer :target_sets
      t.integer :target_reps
      t.decimal :target_weight_kg, precision: 8, scale: 2

      t.timestamps
    end

    add_index :template_exercises, [ :template_block_id, :exercise_id ]
  end
end
