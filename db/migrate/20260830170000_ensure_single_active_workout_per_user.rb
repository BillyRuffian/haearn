class EnsureSingleActiveWorkoutPerUser < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_workouts_on_one_active_per_user'.freeze

  class MigrationWorkout < ActiveRecord::Base
    self.table_name = 'workouts'
  end

  def up
    finish_duplicate_active_workouts
    add_index :workouts, :user_id, unique: true, where: 'finished_at IS NULL', name: INDEX_NAME
  end

  def down
    remove_index :workouts, name: INDEX_NAME
  end

  private

  def finish_duplicate_active_workouts
    duplicate_user_ids = MigrationWorkout
      .where(finished_at: nil)
      .group(:user_id)
      .having('COUNT(*) > 1')
      .pluck(:user_id)

    duplicate_user_ids.each do |user_id|
      active_workouts = MigrationWorkout
        .where(user_id:, finished_at: nil)
        .order(started_at: :desc, created_at: :desc, id: :desc)
        .to_a
      keeper = active_workouts.shift
      finish_time = keeper.started_at || keeper.created_at || Time.current

      active_workouts.each do |workout|
        workout.update_columns(finished_at: [ finish_time, workout.started_at ].compact.max)
      end
    end
  end
end
