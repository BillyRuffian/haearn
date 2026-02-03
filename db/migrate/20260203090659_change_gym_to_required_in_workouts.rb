class ChangeGymToRequiredInWorkouts < ActiveRecord::Migration[8.1]
  def change
    # First delete any workouts without a gym (if any exist)
    Workout.where(gym_id: nil).destroy_all

    change_column_null :workouts, :gym_id, false
  end
end
