module Admin
  class DashboardController < BaseController
    def index
      authorize :admin_dashboard, :index?
      skip_policy_scope

      @total_users = User.count
      @active_users_7d = User.where('updated_at > ?', 7.days.ago).count
      @active_users_30d = User.where('updated_at > ?', 30.days.ago).count
      @new_registrations_30d = User.where('created_at > ?', 30.days.ago).count

      @total_workouts = Workout.count
      @workouts_this_week = Workout.where('created_at > ?', 1.week.ago).count
      @workouts_this_month = Workout.where('created_at > ?', 1.month.ago).count

      @registration_data = registration_chart_data
      @popular_exercises = popular_exercises_data
      @system_info = system_info_data
    end

    private

    def registration_chart_data
      12.downto(0).map do |weeks_ago|
        week_start = weeks_ago.weeks.ago.beginning_of_week
        week_end = week_start.end_of_week
        {
          label: week_start.strftime('%b %d'),
          count: User.where(created_at: week_start..week_end).count
        }
      end
    end

    def popular_exercises_data
      Exercise.joins(workout_exercises: { workout_block: :workout })
        .where(workouts: { created_at: 30.days.ago.. })
        .group('exercises.id', 'exercises.name', 'exercises.primary_muscle_group')
        .order(Arel.sql('COUNT(*) DESC'))
        .limit(10)
        .pluck('exercises.id', 'exercises.name', 'exercises.primary_muscle_group', Arel.sql('COUNT(*)'))
        .map { |id, name, muscle, count| { id: id, name: name, muscle_group: muscle, usage_count: count } }
    end

    def system_info_data
      db_path = ActiveRecord::Base.connection.pool.db_config.configuration_hash[:database]
      {
        db_size: db_path && File.exist?(db_path) ? (File.size(db_path) / 1_048_576.0).round(1) : 'N/A',
        global_exercises: Exercise.global.count,
        user_exercises: Exercise.where.not(user_id: nil).count,
        total_sets: ExerciseSet.count
      }
    end
  end
end
