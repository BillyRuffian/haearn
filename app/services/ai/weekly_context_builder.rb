module Ai
  class WeeklyContextBuilder
    def initialize(user:, week_start:, summary:)
      @user, @week_start, @summary = user, week_start.to_date.beginning_of_week.in_time_zone, summary
    end

    def call
      # Same completion-date membership as the existing weekly email.
      workouts = @user.workouts.where(finished_at: @week_start...(@week_start + 1.week))
      entries = WorkoutExercise.joins(:workout).where(workouts: { id: workouts.select(:id) })
        .includes(:exercise, :machine, :workout_block, :exercise_sets, workout: :program_session_execution).to_a
      groups = entries.group_by { |entry| [ entry.exercise_id, entry.machine_id ] }
      prior = history(groups.keys)
      context = {
        version: 1, goal: 'hypertrophy', preferred_unit: preferred_unit,
        period: { starts_on: @week_start.to_date.iso8601, ends_on: (@week_start.to_date + 6).iso8601,
          membership: 'workout finished_at', timezone: Time.zone.name },
        units: { weight: 'kg', load_volume: 'kg·reps', duration: 'seconds', distance: 'meters' },
        weekly_summary: @summary,
        exercises: groups.sort_by { |(exercise_id, machine_id), _| [ exercise_id, machine_id.to_i ] }.map do |key, rows|
          exercise_context(rows, prior.fetch(key, []))
        end
      }.deep_stringify_keys
      raise InvalidResponse, 'weekly_context_too_large' if JSON.generate(context).bytesize > Config.max_input_bytes

      context
    end

    private

    def preferred_unit
      @summary['preferred_unit'] || @summary[:preferred_unit] || @user.preferred_unit
    end

    def history(pairs)
      return {} if pairs.empty?

      scope = pairs.map { |exercise_id, machine_id| WorkoutExercise.where(exercise_id: exercise_id, machine_id: machine_id) }.reduce(&:or)
        .joins(:workout).where(workouts: { user_id: @user.id, finished_at: ...@week_start })
      TrainingSessionHistory.new(scope: scope, limit: Config.history_sessions).call
    end

    def exercise_context(rows, prior)
      sessions = rows.group_by { |entry| entry.workout.id }.values.map { |entries| TrainingSessionData.session(entries) }
        .sort_by { |session| [ session[:started_at], session[:workout_id] ] }.reverse
      latest = sessions.first
      history = (sessions.drop(1) + prior).first(Config.history_sessions)
      entry = rows.find { |row| row.workout.id == latest[:workout_id] }
      exercise, machine = entry.exercise, entry.machine
      {
        exercise_id: exercise.id, machine_id: machine&.id, exercise_name: exercise.name.truncate(100),
        machine_name: machine&.name&.truncate(100), machine_weight_ratio: machine&.weight_ratio&.to_f,
        display_unit: machine&.display_unit.presence || preferred_unit,
        exercise_type: exercise.exercise_type, has_weight: exercise.has_weight?,
        week_sessions: sessions, sets: latest[:sets], history: history,
        metrics: TrainingProgressionCalculator.new(current: latest, history: history,
          weighted_reps: exercise.has_weight? && exercise.reps?).call
      }
    end
  end
end
