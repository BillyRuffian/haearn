class MakeWorkoutExerciseMachineOptional < ActiveRecord::Migration[8.0]
  def up
    change_column_null :workout_exercises, :machine_id, true
  end

  def down
    if select_value('SELECT 1 FROM workout_exercises WHERE machine_id IS NULL LIMIT 1')
      raise ActiveRecord::IrreversibleMigration, 'equipment-free workout exercises cannot satisfy the old constraint'
    end

    change_column_null :workout_exercises, :machine_id, false
  end
end
