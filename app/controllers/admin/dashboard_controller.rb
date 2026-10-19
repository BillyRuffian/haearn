module Admin
  class DashboardController < BaseController
    def index
      authorize :admin_dashboard, :index?
      skip_policy_scope

      @site_setting = SiteSetting.current
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
      @ai_usage = AiUsageReport.new.call
    end

    def update_registration
      authorize :admin_dashboard, :update_registration?
      enabled = params.require(:site_setting).require(:registrations_enabled)
      raise ActionController::BadRequest unless %w[0 1].include?(enabled)

      setting = SiteSetting.current
      setting.with_lock do
        previous = setting.registrations_enabled?
        setting.update!(registrations_enabled: enabled)
        if previous != setting.registrations_enabled?
          log_admin_action(
            action: 'update_registration_settings', resource: setting,
            metadata: { registrations_enabled: setting.registrations_enabled?, previous_registrations_enabled: previous }
          )
        end
      end

      redirect_to admin_root_path, notice: "New user registrations are #{setting.registrations_enabled? ? 'enabled' : 'disabled'}.", status: :see_other
    end

    private

    def registration_chart_data
      range_start = 12.weeks.ago.beginning_of_week
      range_end = Time.current.end_of_week
      weekly_counts = User.where(created_at: range_start..range_end)
        .group(Arel.sql("strftime('%Y-%W', created_at)"))
        .count

      12.downto(0).map do |weeks_ago|
        week_start = weeks_ago.weeks.ago.beginning_of_week
        {
          label: week_start.strftime('%b %d'),
          count: weekly_counts[week_start.strftime('%Y-%W')] || 0
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
