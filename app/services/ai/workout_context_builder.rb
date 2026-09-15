module Ai
  class WorkoutContextBuilder
    def initialize(workout, history_sessions: Config.history_sessions)
      @workout = workout
      @history_sessions = history_sessions.clamp(1, 8)
    end

    def call
      raise ArgumentError, 'Workout must be complete' unless @workout.completed?

      @groups = current_exercises.group_by { |entry| [ entry.exercise_id, entry.machine_id ] }
      @history = historical_sessions
      @frequency = recent_frequency
      context = {
        version: 1, goal: 'hypertrophy', preferred_unit: @workout.user.preferred_unit,
        units: { weight: 'kg', load_volume: 'kg·reps', duration: 'seconds', distance: 'meters' },
        metric_notes: 'Working completed sets only. Load volume is recorded external load × reps, excluding bands/chains. e1RM uses Epley for normal unassisted 1–10 rep sets. Consecutive-load counts are bounded by supplied history.',
        history_limit: @history_sessions,
        workout: { id: @workout.id, started_at: @workout.started_at&.iso8601,
          finished_at: @workout.finished_at.iso8601, duration_seconds: @workout.duration&.round,
          session_type: @workout.program_session_execution&.display_name&.truncate(100), notes: note(@workout.notes) },
        exercises: @groups.map { |key, entries| exercise_context(key, entries) },
        weekly: TrainingWeeklyMetrics.new(user: @workout.user, through: @workout.finished_at.utc).call
      }
      raise ArgumentError, 'Workout context exceeds size limit' if JSON.generate(context).bytesize > Config.max_input_bytes

      context.deep_stringify_keys
    end

    private

    def current_exercises
      @workout.workout_exercises.includes(:exercise, :machine, :exercise_sets, :workout_block)
        .sort_by { |entry| [ entry.workout_block.position, entry.position, entry.id ] }
    end

    # Rank distinct matching sessions in SQL, so history is bounded per exact pair
    # and query counts do not increase with exercises or years of training.
    def historical_sessions
      return {} if @groups.empty? || @workout.started_at.nil?

      matching = @groups.keys.map { |exercise_id, machine_id| WorkoutExercise.where(exercise_id: exercise_id, machine_id: machine_id) }.reduce(&:or)
      sessions = matching.joins(:workout, :exercise_sets).merge(Workout.completed)
        .where(workouts: { user_id: @workout.user_id, finished_at: ..@workout.finished_at })
        .where('workouts.started_at < :date OR (workouts.started_at = :date AND workouts.id < :id)', date: @workout.started_at, id: @workout.id)
        .where.not(exercise_sets: { completed_at: nil })
        .select('workouts.id AS workout_id, workouts.started_at, workout_exercises.exercise_id, workout_exercises.machine_id').distinct
      ranked = WorkoutExercise.from('coaching_sessions').select(
        'coaching_sessions.*, ROW_NUMBER() OVER (PARTITION BY exercise_id, machine_id ORDER BY started_at DESC, workout_id DESC) AS session_rank'
      )
      selected = WorkoutExercise.with(coaching_sessions: sessions, ranked_coaching_sessions: ranked)
        .from('ranked_coaching_sessions').where('session_rank <= ?', @history_sessions).order('session_rank')
        .pluck(Arel.sql('workout_id'), Arel.sql('exercise_id'), Arel.sql('machine_id'))
        .map { |workout_id, exercise_id, machine_id| { 'workout_id' => workout_id, 'exercise_id' => exercise_id, 'machine_id' => machine_id } }
      exercises = matching.joins(:workout).where(workouts: { id: selected.map { |row| row['workout_id'] } })
        .includes(:exercise_sets, :workout, :workout_block).to_a
      groups = exercises.group_by { |entry| [ entry.exercise_id, entry.machine_id, entry.workout.id ] }
      selected.group_by { |row| [ row['exercise_id'], row['machine_id'] ] }.transform_values do |rows|
        rows.map do |row|
          entries = groups.fetch([ row['exercise_id'], row['machine_id'], row['workout_id'] ])
            .sort_by { |entry| [ entry.workout_block.position, entry.position, entry.id ] }
          { workout_id: row['workout_id'], started_at: entries.first.workout.started_at.iso8601, sets: working_sets(entries) }
        end
      end
    end

    def recent_frequency
      WorkoutExercise.joins(:workout, :exercise_sets)
        .where(workouts: { user_id: @workout.user_id, started_at: (@workout.finished_at - 28.days)..@workout.finished_at,
          finished_at: ..@workout.finished_at })
        .where.not(exercise_sets: { completed_at: nil })
        .where(exercise_sets: { is_warmup: false }, exercise_id: @groups.keys.map(&:first))
        .group(:exercise_id, :machine_id).count('DISTINCT workouts.id')
    end

    def exercise_context(key, entries)
      exercise, machine = entries.first.exercise, entries.first.machine
      current = { sets: working_sets(entries) }
      history = @history.fetch(key, [])
      target = prescribed_target(entries)
      {
        exercise_id: exercise.id, machine_id: machine&.id,
        exercise_name: exercise.name.truncate(100), machine_name: machine&.name&.truncate(100),
        equipment_type: machine&.equipment_type, machine_weight_ratio: machine&.weight_ratio&.to_f,
        display_unit: machine&.display_unit.presence || @workout.user.preferred_unit,
        exercise_type: exercise.exercise_type, has_weight: exercise.has_weight?,
        muscle_group: exercise.primary_muscle_group,
        occurrences: entries.map { |entry| { workout_exercise_id: entry.id, block: entry.workout_block.position,
          notes: note(entry.session_notes), setup: note(entry.persistent_notes) } },
        sets: current[:sets], programmed_target: target, history: history,
        recent_frequency: { days: 28, through: @workout.finished_at.iso8601, sessions: @frequency.fetch(key, 0) },
        metrics: TrainingProgressionCalculator.new(current: current, history: history,
          weighted_reps: exercise.has_weight? && exercise.reps?, target: target).call
      }
    end

    def working_sets(entries)
      entries.flat_map do |entry|
        entry.exercise_sets.select { |set| set.completed_at && !set.is_warmup }
          .sort_by { |set| [ set.completed_at, set.position, set.id ] }.map do |set|
            {
              weight_kg: set.weight_kg&.to_f, reps: set.reps, rpe: set.rpe&.to_f, rir: set.rir,
              duration_seconds: set.duration_seconds, distance_meters: set.distance_meters&.to_f,
              set_type: set.set_type, is_failed: set.is_failed, spotter_assisted: set.spotter_assisted,
              is_amrap: set.is_amrap, partial_reps: set.partial_reps, pain_flag: set.pain_flag,
              equipment: set.equipment_list, band_tension_kg: set.band_tension_kg&.to_f,
              chain_weight_kg: set.chain_weight_kg&.to_f
            }.compact
          end
      end
    end

    def prescribed_target(entries)
      execution = @workout.program_session_execution
      return unless execution

      rows = entries.map { |entry| execution.prescription_for(entry) }
      return if rows.any?(&:nil?) || rows.map { |row| [ row['target_reps'], row['target_weight_kg'] ] }.uniq.size != 1

      { sets: rows.sum { |row| row['target_sets'].to_i }, reps: rows.first['target_reps'],
        weight_kg: rows.first['target_weight_kg']&.to_f, source: 'program_execution_snapshot' }
    end

    def note(value)
      value.presence&.truncate(400)
    end
  end
end
