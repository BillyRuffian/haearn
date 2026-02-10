# Analyzes workout performance and suggests when to increase weight
# Uses RPE/RIR data and rep consistency to recommend progression
class ProgressionSuggester
  # Thresholds for suggesting weight increases
  RPE_THRESHOLD = 8.0  # If average RPE < 8.0, suggest increase
  RIR_THRESHOLD = 2    # If average RIR > 2, suggest increase
  MIN_SESSIONS = 2     # Need at least 2 recent sessions to analyze
  LOOKBACK_DAYS = 21   # Look at last 3 weeks of training

  attr_reader :exercise, :machine, :user, :workout_exercise

  # Initialize suggester for a specific exercise/machine combo
  # @param workout_exercise [WorkoutExercise] current workout exercise
  # @param user [User] current user
  def initialize(workout_exercise:, user:)
    @workout_exercise = workout_exercise
    @exercise = workout_exercise.exercise
    @machine = workout_exercise.machine
    @user = user
  end

  # Check if weight increase should be suggested
  # @return [Hash, nil] suggestion hash or nil if no suggestion
  def suggest
    return nil unless exercise.has_weight?
    return nil unless recent_sessions.count >= MIN_SESSIONS

    # Get recent working sets (non-warmup)
    recent_working_sets = recent_sessions.flat_map do |wo_ex|
      wo_ex.exercise_sets.working.order(:created_at)
    end

    return nil if recent_working_sets.empty?

    # Analyze performance metrics
    avg_weight = recent_working_sets.map(&:weight_kg).compact.sum / recent_working_sets.count.to_f
    avg_reps = recent_working_sets.map(&:reps).compact.sum / recent_working_sets.count.to_f

    # Check RPE/RIR if available
    sets_with_rpe = recent_working_sets.select { |s| s.rpe.present? }
    sets_with_rir = recent_working_sets.select { |s| s.rir.present? }

    avg_rpe = if sets_with_rpe.any?
                sets_with_rpe.map(&:rpe).sum / sets_with_rpe.count.to_f
    end

    avg_rir = if sets_with_rir.any?
                sets_with_rir.map(&:rir).sum / sets_with_rir.count.to_f
    end

    # Determine if progression is recommended
    ready_to_progress = false
    reasons = []

    # Check RPE criterion
    if avg_rpe && avg_rpe < RPE_THRESHOLD
      ready_to_progress = true
      reasons << "RPE averaging #{avg_rpe.round(1)} (comfortable)"
    end

    # Check RIR criterion
    if avg_rir && avg_rir > RIR_THRESHOLD
      ready_to_progress = true
      reasons << "#{avg_rir.round} reps in reserve"
    end

    # Check rep consistency (hitting targets regularly)
    if exercise.exercise_type == 'reps' && avg_reps >= 8
      consistent_reps = recent_working_sets.select { |s| s.reps && s.reps >= avg_reps - 1 }.count
      if consistent_reps.to_f / recent_working_sets.count >= 0.75 # 75% of sets hit target
        ready_to_progress = true
        reasons << "consistently hitting #{avg_reps.round} reps"
      end
    end

    return nil unless ready_to_progress

    # Calculate suggested weight increase
    suggested_weight_kg = calculate_suggested_weight(avg_weight)

    {
      current_weight_kg: avg_weight,
      suggested_weight_kg: suggested_weight_kg,
      increase_kg: suggested_weight_kg - avg_weight,
      reasons: reasons,
      sessions_analyzed: recent_sessions.count,
      avg_rpe: avg_rpe,
      avg_rir: avg_rir,
      avg_reps: avg_reps
    }
  end

  # Generate a human-readable suggestion message
  # @return [String, nil] suggestion message or nil
  def suggestion_message
    suggestion = suggest
    return nil unless suggestion

    current_display = user.format_weight(suggestion[:current_weight_kg])
    suggested_display = user.format_weight(suggestion[:suggested_weight_kg])
    increase_display = user.format_weight(suggestion[:increase_kg])

    "Ready to progress! You've been #{suggestion[:reasons].join(', ')}. " \
    "Try increasing from #{current_display}#{user.preferred_unit} to " \
    "#{suggested_display}#{user.preferred_unit} (+#{increase_display}#{user.preferred_unit})."
  end

  private

  # Get recent workout exercises for this exercise/machine combo
  # @return [ActiveRecord::Relation<WorkoutExercise>]
  def recent_sessions
    @recent_sessions ||= begin
      scope = user.workout_exercises
                  .joins(:workout_block)
                  .joins(workout_block: :workout)
                  .where(exercise: exercise)
                  .where('workouts.finished_at >= ?', LOOKBACK_DAYS.days.ago)
                  .where('workouts.finished_at < ?', workout_exercise.workout.started_at || Time.current)
                  .order(Arel.sql('workouts.finished_at DESC'))
                  .limit(5) # Look at last 5 sessions max

      # Filter by machine if one is selected
      scope = scope.where(machine: machine) if machine

      scope
    end
  end

  # Calculate suggested weight increase based on current weight
  # Larger weights get larger increments
  # @param current_weight_kg [Float] current weight in kg
  # @return [Float] suggested weight in kg
  def calculate_suggested_weight(current_weight_kg)
    # Use smaller increments for lighter weights, larger for heavier
    increment_kg = if current_weight_kg < 20
                     2.5 # 2.5kg for lighter weights
    elsif current_weight_kg < 60
                     5.0 # 5kg for moderate weights
    elsif current_weight_kg < 100
                     7.5 # 7.5kg for heavier weights
    else
                     10.0 # 10kg for very heavy weights
    end

    # Round to nearest 2.5kg for cleaner increments
    ((current_weight_kg + increment_kg) / 2.5).round * 2.5
  end
end
