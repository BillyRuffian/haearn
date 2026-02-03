class ChangeGymToOptionalInWorkouts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :workouts, :gym_id, true
  end
end
