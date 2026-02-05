# Centralized PR (Personal Record) calculation service
# Ensures consistent PR logic across history views and live workout detection
class PrCalculator
  # Calculate all PRs from a collection of workout_exercises
  # Used by history page to show aggregate or per-machine PRs
  def self.calculate_all(workout_exercises, exercise:)
    new(workout_exercises, exercise: exercise).calculate_all
  end

  # Check if a workout_exercise has a volume PR compared to previous sessions
  # Used during live workouts
  def self.volume_pr?(workout_exercise)
    new(nil, workout_exercise: workout_exercise).volume_pr?
  end

  # Check if a set has a weight PR compared to previous sets
  # Used during live workouts  
  def self.weight_pr?(exercise_set)
    new(nil, exercise_set: exercise_set).weight_pr?
  end

  # Get the previous best weight for an exercise+machine combo
  def self.previous_best_weight(workout_exercise)
    new(nil, workout_exercise: workout_exercise).previous_best_weight
  end

  # Calculate PR timeline for dashboard visualization
  # Returns array of PRs achieved over time, scoped by exercise+machine
  # Only counts as PR if there was a previous record to beat
  def self.calculate_timeline(user:, since: 12.months.ago, limit: 100)
    new(nil, user: user).calculate_timeline(since: since, limit: limit)
  end

  def initialize(workout_exercises, exercise: nil, workout_exercise: nil, exercise_set: nil, user: nil)
    @workout_exercises = workout_exercises
    @exercise = exercise
    @workout_exercise = workout_exercise
    @exercise_set = exercise_set
    @user = user
  end

  def calculate_all
    prs = {
      best_set_weight: nil,
      best_set_volume: nil,
      best_session_volume: nil,
      best_e1rm: nil,
      best_reps_at_weight: {}
    }

    return prs if @workout_exercises.blank?

    all_sets = working_sets_from_collection

    return prs if all_sets.empty?
    return prs unless @exercise&.has_weight?

    prs[:best_set_weight] = calculate_best_set_weight(all_sets)
    prs[:best_set_volume] = calculate_best_set_volume(all_sets)
    prs[:best_e1rm] = calculate_best_e1rm(all_sets)
    prs[:best_session_volume] = calculate_best_session_volume

    prs
  end

  def volume_pr?
    return false unless @workout_exercise&.exercise&.has_weight?

    current_volume = session_volume(@workout_exercise)
    return false if current_volume <= 0

    previous_volumes = previous_session_volumes
    return false if previous_volumes.empty?

    current_volume > previous_volumes.max
  end

  def weight_pr?
    return false if @exercise_set&.warmup?
    return false unless @exercise_set&.weight_kg&.positive?
    return false unless @exercise_set&.reps&.positive?

    prev_best = previous_best_weight_for_set
    return false if prev_best.nil?

    @exercise_set.weight_kg > prev_best
  end

  def previous_best_weight
    @previous_best_weight ||= begin
      return nil unless @workout_exercise

      ExerciseSet
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: {
          exercise_id: @workout_exercise.exercise_id,
          machine_id: @workout_exercise.machine_id
        })
        .where(workouts: { user_id: @workout_exercise.workout.user_id })
        .where.not(workouts: { id: @workout_exercise.workout.id })
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .maximum(:weight_kg)
    end
  end

  private

  # Volume calculation - used in multiple places
  def session_volume(workout_exercise)
    workout_exercise.exercise_sets
      .select { |s| !s.is_warmup }
      .sum { |s| set_volume(s) }
  end

  def set_volume(set)
    (set.weight_kg || 0) * (set.reps || 0)
  end

  def working_sets_from_collection
    @workout_exercises.flat_map(&:exercise_sets).select { |s| !s.is_warmup }
  end

  def calculate_best_set_weight(sets)
    best = sets.max_by(&:weight_kg)
    return nil unless best&.weight_kg

    {
      weight_kg: best.weight_kg,
      reps: best.reps,
      date: best.completed_at&.to_date || best.created_at.to_date
    }
  end

  def calculate_best_set_volume(sets)
    best = sets.max_by { |s| set_volume(s) }
    volume = set_volume(best)
    return nil if volume <= 0

    {
      weight_kg: best.weight_kg,
      reps: best.reps,
      volume: volume,
      date: best.completed_at&.to_date || best.created_at.to_date
    }
  end

  def calculate_best_e1rm(sets)
    best_value = 0
    best_set = nil

    sets.each do |s|
      next unless s.weight_kg && s.reps&.positive?

      e1rm = OneRmCalculator.calculate_average(s.weight_kg, s.reps)
      if e1rm && e1rm > best_value
        best_value = e1rm
        best_set = s
      end
    end

    return nil unless best_set

    {
      e1rm_kg: best_value,
      weight_kg: best_set.weight_kg,
      reps: best_set.reps,
      date: best_set.completed_at&.to_date || best_set.created_at.to_date
    }
  end

  def calculate_best_session_volume
    session_data = @workout_exercises.map do |we|
      { workout_exercise: we, volume: session_volume(we) }
    end

    best = session_data.max_by { |d| d[:volume] }
    return nil unless best && best[:volume] > 0

    workout = best[:workout_exercise].workout_block.workout
    {
      volume: best[:volume],
      workout: workout,
      date: workout.started_at.to_date
    }
  end

  def previous_session_volumes
    WorkoutExercise
      .joins(:workout_block)
      .joins('INNER JOIN workouts ON workouts.id = workout_blocks.workout_id')
      .where(exercise_id: @workout_exercise.exercise_id, machine_id: @workout_exercise.machine_id)
      .where('workouts.user_id = ?', @workout_exercise.workout.user_id)
      .where('workouts.id != ?', @workout_exercise.workout.id)
      .where('workouts.finished_at IS NOT NULL')
      .includes(:exercise_sets)
      .map { |we| session_volume(we) }
  end

  def previous_best_weight_for_set
    return nil unless @exercise_set&.workout_exercise

    we = @exercise_set.workout_exercise
    ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workout_exercises: { exercise_id: we.exercise_id, machine_id: we.machine_id })
      .where(workouts: { user_id: we.workout.user_id })
      .where.not(workouts: { id: we.workout.id })
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .maximum(:weight_kg)
  end

  public

  # Calculate PR timeline for dashboard - tracks when PRs were achieved
  # Scoped by exercise+machine, only counts as PR if beating a previous record
  def calculate_timeline(since:, limit:)
    prs = []

    # Get all workout exercises from the time period
    workout_exercises = WorkoutExercise
      .joins(workout_block: :workout)
      .includes(:exercise, :machine, :exercise_sets)
      .where(workouts: { user_id: @user.id })
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })

    # Group by exercise+machine combination for proper PR scoping
    by_exercise_machine = workout_exercises.group_by { |we| [we.exercise_id, we.machine_id] }

    by_exercise_machine.each do |(exercise_id, machine_id), wes|
      exercise = wes.first.exercise
      machine = wes.first.machine
      next unless exercise&.has_weight?

      # Sort by workout date to process chronologically
      sorted_wes = wes.sort_by { |we| we.workout_block.workout.finished_at }

      # Get all historical sets BEFORE the time period to establish baseline
      historical_best_weight = ExerciseSet
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: exercise_id, machine_id: machine_id })
        .where(workouts: { user_id: @user.id })
        .where('workouts.finished_at < ?', since)
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .maximum(:weight_kg) || 0

      historical_best_volume = 0
      WorkoutExercise
        .joins(workout_block: :workout)
        .includes(:exercise_sets)
        .where(exercise_id: exercise_id, machine_id: machine_id)
        .where(workouts: { user_id: @user.id })
        .where('workouts.finished_at < ?', since)
        .where.not(workouts: { finished_at: nil })
        .each do |we|
          vol = we.exercise_sets.select { |s| !s.is_warmup }.sum { |s| set_volume(s) }
          historical_best_volume = vol if vol > historical_best_volume
        end

      # Track running best as we go through the time period
      best_weight = historical_best_weight
      best_session_volume = historical_best_volume

      sorted_wes.each do |we|
        workout = we.workout_block.workout
        date = workout.finished_at.to_date
        working_sets = we.exercise_sets.select { |s| !s.is_warmup && s.weight_kg.present? && s.reps&.positive? }

        # Check each set for weight PR
        working_sets.each do |set|
          if set.weight_kg > best_weight
            # Only count as PR if there was a previous record (best_weight > 0)
            if best_weight > 0
              prs << {
                exercise: exercise.name,
                machine: machine&.name,
                date: date.to_s,
                weight: @user.display_weight(set.weight_kg).round,
                reps: set.reps || 0,
                type: 'weight'
              }
            end
            best_weight = set.weight_kg
          end
        end

        # Check session volume PR
        current_session_volume = working_sets.sum { |s| set_volume(s) }
        if current_session_volume > best_session_volume
          # Only count as PR if there was a previous record
          if best_session_volume > 0
            prs << {
              exercise: exercise.name,
              machine: machine&.name,
              date: date.to_s,
              weight: @user.display_weight(working_sets.max_by(&:weight_kg)&.weight_kg || 0).round,
              reps: working_sets.sum { |s| s.reps || 0 },
              type: 'session_volume'
            }
          end
          best_session_volume = current_session_volume
        end
      end
    end

    # Sort by date and limit
    prs.sort_by { |pr| pr[:date] }.last(limit)
  end
end
