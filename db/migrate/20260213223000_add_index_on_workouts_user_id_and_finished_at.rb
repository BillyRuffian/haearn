class AddIndexOnWorkoutsUserIdAndFinishedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :workouts, [ :user_id, :finished_at ]
  end
end
