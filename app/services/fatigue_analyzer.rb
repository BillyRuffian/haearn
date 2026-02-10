# frozen_string_literal: true

# Analyzes workout performance against baseline to detect fatigue
#
# Compares current session performance to recent baseline:
# - Weight lifted (volume)
# - Reps completed
# - RPE (perceived effort)
#
# Returns fatigue status:
# - :fresh - performing above baseline
# - :normal - performing at baseline
# - :fatigued - performing below baseline
# - :very_fatigued - significantly below baseline
class FatigueAnalyzer
  BASELINE_SESSIONS = 10 # Use last 10 sessions for baseline
  LOOKBACK_DAYS = 60 # Only consider sessions within 60 days
  FRESH_THRESHOLD = 0.05 # 5% above baseline
  FATIGUED_THRESHOLD = -0.10 # 10% below baseline
  VERY_FATIGUED_THRESHOLD = -0.20 # 20% below baseline

  attr_reader :workout_exercise, :user

  def initialize(workout_exercise:, user:)
    @workout_exercise = workout_exercise
    @user = user
  end

  # Returns hash with fatigue analysis or nil if insufficient data
  # {
  #   status: :fresh | :normal | :fatigued | :very_fatigued,
  #   performance_vs_baseline: 0.05, # 5% above baseline
  #   current_performance: { volume_kg: 1000, avg_reps: 10, avg_rpe: 7.5 },
  #   baseline_performance: { volume_kg: 952, avg_reps: 9.5, avg_rpe: 7.0 },
  #   sessions_analyzed: 8
  # }
  def analyze
    return nil unless has_current_performance?
    return nil if baseline_sessions.empty?

    current = calculate_current_performance
    baseline = calculate_baseline_performance
    performance_delta = calculate_performance_delta(current, baseline)

    {
      status: determine_status(performance_delta),
      performance_vs_baseline: performance_delta.round(3),
      current_performance: current,
      baseline_performance: baseline,
      sessions_analyzed: baseline_sessions.count,
      factors: identify_factors(current, baseline)
    }
  end

  # Human-readable message about fatigue status
  def status_message
    result = analyze
    return nil unless result

    case result[:status]
    when :fresh
      "💪 Performing #{(result[:performance_vs_baseline] * 100).round}% above baseline - you're fresh!"
    when :normal
      '✅ Performing at baseline - normal training capacity'
    when :fatigued
      "⚠️ Performing #{(result[:performance_vs_baseline].abs * 100).round}% below baseline - consider lighter load"
    when :very_fatigued
      "🚨 Performing #{(result[:performance_vs_baseline].abs * 100).round}% below baseline - high fatigue detected"
    end
  end

  # Badge color for UI display
  def status_color
    result = analyze
    return 'secondary' unless result

    case result[:status]
    when :fresh then 'success'
    when :normal then 'info'
    when :fatigued then 'warning'
    when :very_fatigued then 'danger'
    end
  end

  private

  def has_current_performance?
    workout_exercise.sets.working.any?
  end

  def baseline_sessions
    @baseline_sessions ||= begin
      cutoff_date = LOOKBACK_DAYS.days.ago

      WorkoutExercise
        .joins(:workout, :sets)
        .where(exercise_id: workout_exercise.exercise_id)
        .where.not(id: workout_exercise.id) # Exclude current session
        .where('workouts.finished_at IS NOT NULL') # Only completed workouts
        .where('workouts.finished_at >= ?', cutoff_date)
        .where('workouts.user_id = ?', user.id)
        .where('exercise_sets.is_warmup = ?', false) # Only working sets
        .tap do |scope|
          # Filter by machine if specified (same machine only)
          if workout_exercise.machine_id.present?
            scope.where(machine_id: workout_exercise.machine_id)
          end
        end
        .distinct
        .order(Arel.sql('workouts.finished_at DESC'))
        .limit(BASELINE_SESSIONS)
    end
  end

  def calculate_current_performance
    sets = workout_exercise.sets.working
    total_volume = sets.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
    avg_reps = sets.average(:reps)&.to_f || 0
    avg_rpe = sets.where.not(rpe: nil).average(:rpe)&.to_f

    {
      volume_kg: total_volume.round(2),
      avg_reps: avg_reps.round(2),
      avg_rpe: avg_rpe&.round(2)
    }
  end

  def calculate_baseline_performance
    all_sets = ExerciseSet
      .joins(workout_exercise: :workout)
      .where(workout_exercise_id: baseline_sessions.pluck(:id))
      .where(is_warmup: false)

    # Group by session and calculate per-session metrics, then average across sessions
    session_volumes = baseline_sessions.map do |we|
      we.sets.working.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
    end

    avg_volume = session_volumes.sum / baseline_sessions.count.to_f

    {
      volume_kg: avg_volume.round(2),
      avg_reps: all_sets.average(:reps)&.to_f&.round(2) || 0,
      avg_rpe: all_sets.where.not(rpe: nil).average(:rpe)&.to_f&.round(2)
    }
  end

  # Calculate overall performance delta (weighted composite score)
  def calculate_performance_delta(current, baseline)
    return 0 if baseline[:volume_kg].zero?

    # Volume is primary indicator (70% weight)
    volume_delta = (current[:volume_kg] - baseline[:volume_kg]) / baseline[:volume_kg]

    # Reps contribute 30%
    reps_delta = if baseline[:avg_reps] > 0
      (current[:avg_reps] - baseline[:avg_reps]) / baseline[:avg_reps]
    else
      0
    end

    # RPE inverted (lower is better) - if available, adjust score
    rpe_adjustment = if current[:avg_rpe] && baseline[:avg_rpe]
      # If RPE is higher (worse), subtract from score
      # If RPE is lower (better), add to score
      -(current[:avg_rpe] - baseline[:avg_rpe]) / 10.0
    else
      0
    end

    (volume_delta * 0.7) + (reps_delta * 0.3) + rpe_adjustment
  end

  def determine_status(performance_delta)
    return :very_fatigued if performance_delta <= VERY_FATIGUED_THRESHOLD
    return :fatigued if performance_delta <= FATIGUED_THRESHOLD
    return :fresh if performance_delta >= FRESH_THRESHOLD

    :normal
  end

  def identify_factors(current, baseline)
    factors = []

    # Volume comparison
    if current[:volume_kg] < baseline[:volume_kg] * 0.9
      factors << 'volume_low'
    elsif current[:volume_kg] > baseline[:volume_kg] * 1.1
      factors << 'volume_high'
    end

    # Reps comparison
    if current[:avg_reps] < baseline[:avg_reps] * 0.9
      factors << 'reps_low'
    elsif current[:avg_reps] > baseline[:avg_reps] * 1.1
      factors << 'reps_high'
    end

    # RPE comparison (if available)
    if current[:avg_rpe] && baseline[:avg_rpe]
      if current[:avg_rpe] > baseline[:avg_rpe] + 1
        factors << 'effort_high'
      elsif current[:avg_rpe] < baseline[:avg_rpe] - 1
        factors << 'effort_low'
      end
    end

    factors
  end
end
