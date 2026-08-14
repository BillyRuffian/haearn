class WorkoutExerciseVolumeComparison
  class << self
    def for(workout_exercise)
      for_many([ workout_exercise ]).fetch(workout_exercise.id)
    end

    def for_many(workout_exercises)
      eligible = workout_exercises.select { |workout_exercise| eligible?(workout_exercise) }
      previous_maxima = previous_maxima_for(eligible)

      workout_exercises.each_with_object({}) do |workout_exercise, comparisons|
        current = current_volume(workout_exercise)
        previous_max = previous_maxima.fetch(combo_for(workout_exercise), 0)

        comparisons[workout_exercise.id] = {
          current_volume_kg: current,
          previous_max_volume_kg: previous_max,
          max_volume_kg: [ current, previous_max ].max,
          volume_pr: previous_max.positive? && current > previous_max
        }
      end
    end

    private

    def eligible?(workout_exercise)
      workout_exercise.exercise.has_weight? && workout_exercise.exercise.exercise_type == 'reps'
    end

    def current_volume(workout_exercise)
      return 0 unless eligible?(workout_exercise)

      workout_exercise.exercise_sets
        .select { |set| set.is_warmup == false }
        .sum { |set| set.weight_kg.to_d * set.reps.to_i }
    end

    def previous_maxima_for(workout_exercises)
      return {} if workout_exercises.empty?

      user = workout_exercises.first.workout.user
      desired_combos = workout_exercises.map { |workout_exercise| combo_for(workout_exercise) }.to_set
      current_workout_ids = workout_exercises.map { |workout_exercise| workout_exercise.workout.id }.uniq

      rows = user.exercise_sets
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: desired_combos.map(&:first).uniq })
        .where.not(workouts: { id: current_workout_ids })
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil, reps: nil)
        .where('exercise_sets.reps > 0')
        .group(
          Arel.sql('workout_exercises.id'),
          Arel.sql('workout_exercises.exercise_id'),
          Arel.sql('workout_exercises.machine_id')
        )
        .pluck(
          Arel.sql('workout_exercises.exercise_id'),
          Arel.sql('workout_exercises.machine_id'),
          Arel.sql('SUM(exercise_sets.weight_kg * exercise_sets.reps)')
        )

      rows.each_with_object(Hash.new(0)) do |(exercise_id, machine_id, volume), maxima|
        combo = [ exercise_id, machine_id ]
        next unless desired_combos.include?(combo)

        maxima[combo] = volume if volume > maxima[combo]
      end
    end

    def combo_for(workout_exercise)
      [ workout_exercise.exercise_id, workout_exercise.machine_id ]
    end
  end
end
