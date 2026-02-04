class AddPrimaryMuscleGroupToExercises < ActiveRecord::Migration[8.1]
  def change
    add_column :exercises, :primary_muscle_group, :string
  end
end
