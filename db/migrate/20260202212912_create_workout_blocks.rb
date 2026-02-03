class CreateWorkoutBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_blocks do |t|
      t.references :workout, null: false, foreign_key: true
      t.integer :position
      t.integer :rest_seconds

      t.timestamps
    end
  end
end
