class TrainingSessionHistory
  def initialize(scope:, limit:)
    @scope, @limit = scope, limit.clamp(1, 8)
  end

  # The caller supplies a user-, equipment-, and date-scoped relation joined to workouts.
  # Rank distinct sessions in SQL to keep both memory and query counts bounded.
  def call
    sessions = @scope.joins(:exercise_sets).where.not(exercise_sets: { completed_at: nil })
      .select('workouts.id AS workout_id, workouts.started_at, workout_exercises.exercise_id, workout_exercises.machine_id').distinct
    ranked = WorkoutExercise.from('coaching_sessions').select(
      'coaching_sessions.*, ROW_NUMBER() OVER (PARTITION BY exercise_id, machine_id ORDER BY started_at DESC, workout_id DESC) AS session_rank'
    )
    selected = WorkoutExercise.with(coaching_sessions: sessions, ranked_coaching_sessions: ranked)
      .from('ranked_coaching_sessions').where('session_rank <= ?', @limit).order('session_rank')
      .pluck(Arel.sql('workout_id'), Arel.sql('exercise_id'), Arel.sql('machine_id'))
    entries = @scope.where(workouts: { id: selected.map(&:first) }).includes(:exercise_sets, :workout, :workout_block)
    grouped = entries.group_by { |entry| [ entry.workout.id, entry.exercise_id, entry.machine_id ] }
    selected.group_by { |_, exercise_id, machine_id| [ exercise_id, machine_id ] }.transform_values do |rows|
      rows.map { |key| TrainingSessionData.session(grouped.fetch(key)) }
    end
  end
end
