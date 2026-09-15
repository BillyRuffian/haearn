class TrainingWeeklyMetrics
  WEEK_SQL = "date(workouts.started_at, '-6 days', 'weekday 1')".freeze

  def initialize(user:, through:)
    @user, @through = user, through
  end

  def call
    first_week = @through.beginning_of_week - 3.weeks
    workouts = @user.workouts.completed.where(started_at: first_week..@through, finished_at: ..@through)
    sets = ExerciseSet.completed.working.joins(workout_exercise: [ :exercise, :workout ])
      .where(workouts: { id: workouts.select(:id) })
    rows = sets.group(Arel.sql(WEEK_SQL), 'exercises.primary_muscle_group').pluck(
      Arel.sql(WEEK_SQL), 'exercises.primary_muscle_group', Arel.sql('COUNT(*)'),
      Arel.sql('COUNT(DISTINCT workouts.id)'),
      Arel.sql('SUM(CASE WHEN exercise_sets.rpe IS NOT NULL OR exercise_sets.rir IS NOT NULL THEN 1 ELSE 0 END)'),
      Arel.sql('SUM(CASE WHEN exercise_sets.rpe >= 7 OR exercise_sets.rir <= 3 THEN 1 ELSE 0 END)'),
      Arel.sql("SUM(CASE WHEN exercises.has_weight = 1 AND exercises.exercise_type = 'reps' THEN COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0) ELSE 0 END)")
    )
    counts = workouts.group(Arel.sql(WEEK_SQL)).count
    {
      timezone: 'UTC',
      hard_set_definition: 'Recorded RPE >= 7 or RIR <= 3; unknown effort is not counted as hard. Primary muscle only.',
      weeks: 4.times.map do |index|
        week = (first_week + index.weeks).to_date.iso8601
        muscles = rows.select { |row| row[0] == week }.map do |_, muscle, count, frequency, effort_count, hard_count, volume|
          { muscle: muscle, working_sets: count, sessions: frequency, effort_recorded_sets: effort_count,
            known_hard_sets: hard_count, load_volume_kg_reps: volume.to_f.round(3) }
        end
        { starts_on: week, through: [ Date.iso8601(week).end_of_week, @through.to_date ].min.iso8601,
          partial_week: index == 3, workouts: counts.fetch(week, 0), muscles: muscles.sort_by { |row| row[:muscle].to_s } }
      end
    }
  end
end
