# frozen_string_literal: true

# Builds the data hashes used by dashboard pages so the controller can stay
# focused on routing and rendering while the underlying analytics calculations
# remain unchanged.
class DashboardPageDataBuilder
  def initialize(user:, analytics_fetcher:)
    @user = user
    @analytics_fetcher = analytics_fetcher
  end

  def index_data
    shared_analytics = shared_analytics_data
    pr_timeline_data = shared_analytics.fetch(:pr_timeline_data)

    shared_analytics.merge(
      workouts_this_week: workouts_this_week,
      volume_this_week: volume_this_week,
      prs_this_month: prs_this_month(pr_timeline_data),
      current_weight_kg: @user.body_metrics.current_weight_kg,
      recent_workouts: recent_workouts,
      fatigue_data: fatigue_data,
      readiness_alerts: readiness_alerts,
      today_session: today_session_data
    )
  end

  def analytics_data
    shared_analytics_data
  end

  private

  def shared_analytics_data
    @shared_analytics_data ||= {
      pr_timeline_data: analytics('pr_timeline'),
      workout_frequency: analytics('workout_frequency'),
      consistency_data: analytics('consistency'),
      rep_range_data: analytics('rep_range_distribution'),
      session_duration_data: session_duration_data,
      exercise_frequency_data: analytics('exercise_frequency'),
      streak_data: analytics('streaks'),
      week_comparison_data: analytics('week_comparison'),
      tonnage_data: analytics('tonnage'),
      training_period_totals: analytics('training_period_totals'),
      plateau_data: analytics('plateaus'),
      training_density_data: analytics('training_density'),
      muscle_group_data: analytics('muscle_group_volume'),
      muscle_balance_data: analytics('muscle_balance')
    }
  end

  def analytics(key)
    @analytics_fetcher.call(key)
  end

  def workouts_this_week
    @user.workouts
      .where(finished_at: 1.week.ago.beginning_of_day..Time.current)
      .count
  end

  def volume_this_week
    volume = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: 1.week.ago.beginning_of_day..Time.current)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    display_volume(volume)
  end

  def prs_this_month(pr_timeline_data)
    start_of_month = Time.current.beginning_of_month.to_date.to_s
    pr_timeline_data.count { |pr| pr[:date] >= start_of_month }
  end

  def recent_workouts
    @user.workouts
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .limit(5)
  end

  def fatigue_data
    workout = @user.active_workout
    return [] unless workout

    workout.workout_exercises.includes(:exercise, :machine, :exercise_sets).filter_map do |workout_exercise|
      next if workout_exercise.exercise_sets.working.empty?

      analyzer = FatigueAnalyzer.new(workout_exercise: workout_exercise, user: @user)
      analysis = analyzer.analyze
      next unless analysis

      {
        workout_exercise: workout_exercise,
        analysis: analysis,
        message: analyzer.status_message,
        color: analyzer.status_color
      }
    end
  end

  def readiness_alerts
    recent_combos = @user.workouts
      .where.not(finished_at: nil)
      .where('finished_at >= ?', 30.days.ago)
      .joins(workout_exercises: :exercise)
      .pluck(Arel.sql('DISTINCT exercises.id, workout_exercises.machine_id'))
      .first(10)

    exercise_ids = recent_combos.map(&:first).compact.uniq
    machine_ids = recent_combos.map(&:last).compact.uniq
    exercises_by_id = Exercise.where(id: exercise_ids).index_by(&:id)
    machines_by_id = Machine.where(id: machine_ids).index_by(&:id)

    recent_combos.filter_map do |exercise_id, machine_id|
      exercise = exercises_by_id[exercise_id]
      next unless exercise

      machine = machine_id ? machines_by_id[machine_id] : nil
      checker = ProgressionReadinessChecker.new(exercise: exercise, user: @user, machine: machine)
      readiness = checker.check_readiness
      next unless readiness

      {
        exercise: exercise,
        machine: machine,
        readiness: readiness,
        message: checker.readiness_message
      }
    end
  end

  def session_duration_data
    @user.workouts
      .left_joins(:gym)
      .where.not(finished_at: nil)
      .where.not(started_at: nil)
      .order(finished_at: :desc)
      .limit(20)
      .pluck(
        :finished_at,
        Arel.sql('ROUND((julianday(workouts.finished_at) - julianday(workouts.started_at)) * 1440.0)'),
        Arel.sql('gyms.name')
      )
      .map do |finished_at, duration, gym_name|
        {
          date: finished_at.to_date.to_s,
          duration: duration.to_i,
          gym: gym_name || 'Unknown'
        }
      end.reverse
  end

  def today_session_data
    cycle = @user.active_program_cycle
    return { cycle: nil, sessions: [], exercise_count: 0 } unless cycle

    sessions = cycle.scheduled_sessions_on(Date.current).to_a
    {
      cycle: cycle,
      sessions: sessions,
      exercise_count: sessions.sum do |session|
        session.workout_template.template_blocks.sum { |block| block.template_exercises.size }
      end
    }
  end

  def display_volume(volume)
    if @user.preferred_unit == 'lbs'
      (volume * 2.20462).round
    else
      volume.round
    end
  end
end
