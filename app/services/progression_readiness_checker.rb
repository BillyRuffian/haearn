# frozen_string_literal: true

# Checks if user is ready to progress based on rep consistency
#
# Different from ProgressionSuggester (which uses RPE/RIR auto-regulation):
# This checks if user consistently hits rep targets over multiple sessions,
# indicating they've adapted and are ready for more weight.
#
# Criteria:
# - User has completed 3+ recent sessions
# - Consistently hitting or exceeding target rep range (e.g., 8-12 reps)
# - Weight has been stable (not decreasing)
# - No recent progression (hasn't increased weight in last 2 sessions)
class ProgressionReadinessChecker
  MIN_CONSISTENT_SESSIONS = 3 # Need 3 consecutive sessions hitting targets
  LOOKBACK_DAYS = 30 # Only consider sessions within 30 days
  REP_TARGET_PERCENTILE = 0.75 # 75% of sets should hit target reps

  attr_reader :exercise, :user, :machine

  def initialize(exercise:, user:, machine: nil)
    @exercise = exercise
    @user = user
    @machine = machine
  end

  # Returns hash with readiness analysis or nil if not ready
  # {
  #   ready: true,
  #   sessions_analyzed: 4,
  #   avg_weight_kg: 80.0,
  #   avg_reps: 11.5,
  #   rep_range: [10, 12],
  #   consistency_rate: 0.85, # 85% of sets hit target
  #   message: "You've hit 10+ reps for 4 consecutive sessions. Ready to increase weight!"
  # }
  def check_readiness
    return nil if recent_sessions.count < MIN_CONSISTENT_SESSIONS

    rep_range = detect_rep_range
    return nil unless rep_range # Can't determine target rep range

    consistency = calculate_consistency(rep_range)
    return nil if consistency[:rate] < REP_TARGET_PERCENTILE

    # Check if weight has been stable/increasing
    return nil if weight_trending_down?

    # Check if recently progressed (don't spam suggestions)
    return nil if recently_progressed?

    {
      ready: true,
      sessions_analyzed: recent_sessions.count,
      avg_weight_kg: consistency[:avg_weight],
      avg_reps: consistency[:avg_reps],
      rep_range: rep_range,
      consistency_rate: consistency[:rate],
      message: generate_message(recent_sessions.count, consistency[:avg_reps], rep_range)
    }
  end

  # User-friendly message for dashboard alerts
  def readiness_message
    result = check_readiness
    return nil unless result

    result[:message]
  end

  private

  def recent_sessions
    @recent_sessions ||= begin
      cutoff_date = LOOKBACK_DAYS.days.ago

      scope = user.workout_exercises
        .joins(:exercise_sets, workout_block: :workout)
        .where(exercise_id: exercise.id)
        .where('workouts.finished_at IS NOT NULL')
        .where('workouts.finished_at >= ?', cutoff_date)
        .where('exercise_sets.is_warmup = ?', false)

      # Filter by machine if specified
      scope = scope.where(machine_id: machine.id) if machine

      scope
        .distinct
        .order(Arel.sql('workouts.finished_at DESC'))
        .limit(10)
    end
  end

  # Detect target rep range from recent sessions (modal range)
  def detect_rep_range
    all_reps = recent_sessions.flat_map { |we| we.exercise_sets.working.pluck(:reps).compact }
    return nil if all_reps.empty?

    # Find the most common rep count (mode)
    mode_reps = all_reps.group_by(&:itself).values.max_by(&:count)&.first
    return nil unless mode_reps

    # Define range as mode ± 2 reps (e.g., if mode is 10, range is 8-12)
    [ mode_reps - 2, mode_reps + 2 ]
  end

  # Calculate what % of sets hit the target rep range
  def calculate_consistency(rep_range)
    all_working_sets = ExerciseSet
      .joins(workout_exercise: :workout)
      .where(workout_exercise_id: recent_sessions.pluck(:id))
      .where(is_warmup: false)

    total_sets = all_working_sets.count
    return { rate: 0, avg_weight: 0, avg_reps: 0 } if total_sets.zero?

    sets_hitting_target = all_working_sets.where('reps >= ?', rep_range[0]).count

    {
      rate: sets_hitting_target / total_sets.to_f,
      avg_weight: all_working_sets.average(:weight_kg)&.to_f&.round(2) || 0,
      avg_reps: all_working_sets.average(:reps)&.to_f&.round(2) || 0
    }
  end

  # Check if weight is decreasing over recent sessions
  def weight_trending_down?
    return false if recent_sessions.count < 2

    weights = recent_sessions.reverse.map do |we|
      we.exercise_sets.working.average(:weight_kg)&.to_f || 0
    end

    # Simple trend: is most recent session lighter than oldest in window?
    weights.last < weights.first * 0.95 # 5% decrease = trending down
  end

  # Check if user recently increased weight (within last 2 sessions)
  def recently_progressed?
    return false if recent_sessions.count < 3

    last_two = recent_sessions[0..1].map do |we|
      we.exercise_sets.working.average(:weight_kg)&.to_f || 0
    end

    older_sessions = recent_sessions[2..-1].map do |we|
      we.exercise_sets.working.average(:weight_kg)&.to_f || 0
    end

    avg_recent = last_two.sum / last_two.count
    avg_older = older_sessions.sum / older_sessions.count

    # Recently increased if recent avg is 2.5% higher
    avg_recent > avg_older * 1.025
  end

  def generate_message(session_count, avg_reps, rep_range)
    exercise_name = machine ? "#{exercise.name} (#{machine.name})" : exercise.name
    "You've consistently hit #{rep_range[0]}+ reps on #{exercise_name} for #{session_count} sessions (avg: #{avg_reps.round(1)}). Ready to progress! 💪"
  end
end
