# frozen_string_literal: true

# Builds user-scoped relative-strength analytics from completed free-weight sets.
# It intentionally requires explicit Exercise#strength_lift_key metadata and an
# opted-in user scoring category; machine contexts are never mixed into SBD data.
class StrengthAnalyticsCalculator
  LIFT_KEYS = %w[squat bench deadlift overhead_press].freeze
  SBD_KEYS = %w[squat bench deadlift].freeze
  MAX_BODYWEIGHT_AGE_DAYS = 30

  def initialize(user:)
    @user = user
  end

  def lift_ratios
    weights = @user.body_metrics.with_weight.order(:measured_at).pluck(:measured_at, :weight_kg)
    return empty_ratios('Log a bodyweight to view lift ratios.') if weights.empty?

    best_lifts = best_lifts_from(qualifying_set_rows)
    return empty_ratios('Log completed free-weight sets for a marked strength lift.') if best_lifts.empty?

    details = LIFT_KEYS.index_with do |key|
      lift = best_lifts[key]
      next unless lift

      measured_at, bodyweight_kg = latest_prior_bodyweight(weights, lift[:finished_at])
      next unless measured_at

      lift.slice(:exercise_name, :estimated_1rm_kg, :date).merge(
        bodyweight_kg: bodyweight_kg.to_f.round(2),
        bodyweight_date: measured_at.to_date.iso8601,
        ratio: (lift[:estimated_1rm_kg] / bodyweight_kg).round(2)
      )
    end
    values = LIFT_KEYS.map { |key| details[key]&.fetch(:ratio) }
    return empty_ratios('Pair a marked free-weight lift with a bodyweight measured on or before that session within 30 days.') if values.compact.empty?

    {
      labels: LIFT_KEYS.map(&:titleize),
      values: values,
      details: details,
      reason: nil
    }
  end

  def score_trend
    return empty_scores('Choose a relative-strength scoring category in Settings to calculate Wilks and DOTS.') unless User::STRENGTH_SCORING_SEXES.include?(@user.strength_scoring_sex)

    weights = @user.body_metrics.with_weight.order(:measured_at).pluck(:measured_at, :weight_kg)
    return empty_scores('Log bodyweight alongside your training to calculate Wilks and DOTS.') if weights.empty?

    best_lifts = {}
    weight_index = 0
    points = []
    qualifying_set_rows.each do |lift_key, exercise_name, weight_kg, reps, finished_at|
      estimate = OneRmCalculator.calculate_average(weight_kg, reps)
      next unless estimate

      existing = best_lifts[lift_key]
      best_lifts[lift_key] = { estimated_1rm_kg: estimate, exercise_name: exercise_name } if existing.nil? || estimate > existing[:estimated_1rm_kg]
      next unless SBD_KEYS.all? { |key| best_lifts[key] }

      while weight_index + 1 < weights.length && weights[weight_index + 1].first <= finished_at
        weight_index += 1
      end
      measured_at, bodyweight_kg = weights[weight_index]
      next if measured_at > finished_at || measured_at < finished_at - MAX_BODYWEIGHT_AGE_DAYS.days

      total_kg = SBD_KEYS.sum { |key| best_lifts[key][:estimated_1rm_kg] }
      sex = @user.strength_scoring_sex
      wilks = WilksCalculator.new(bodyweight_kg:, total_kg:, sex:).calculate
      dots = DotsCalculator.new(bodyweight_kg:, total_kg:, sex:).calculate
      next unless wilks && dots

      point = { date: finished_at.to_date.iso8601, wilks: wilks, dots: dots, total_kg: total_kg.round(1), bodyweight_kg: bodyweight_kg.to_f.round(2) }
      points << point unless points.last&.slice(:wilks, :dots, :total_kg, :bodyweight_kg) == point.slice(:wilks, :dots, :total_kg, :bodyweight_kg)
    end

    return empty_scores('Complete marked free-weight squat, bench, and deadlift sets with a recent weigh-in to start a trend.') if points.empty?

    { points: points.last(100), reason: nil }
  end

  private

  def qualifying_set_rows
    @qualifying_set_rows ||= @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where.not(workouts: { finished_at: nil })
      .where(workout_exercises: { machine_id: nil })
      .where(exercises: { strength_lift_key: LIFT_KEYS })
      .where(is_warmup: false)
      .where.not(weight_kg: nil, reps: nil)
      .where('exercise_sets.reps BETWEEN 1 AND 30')
      .order(Arel.sql('workouts.finished_at ASC, exercise_sets.completed_at ASC, exercise_sets.id ASC'))
      .pluck(Arel.sql('exercises.strength_lift_key'), Arel.sql('exercises.name'), :weight_kg, :reps, Arel.sql('workouts.finished_at'))
  end

  def best_lifts_from(rows)
    rows.each_with_object({}) do |(lift_key, exercise_name, weight_kg, reps, finished_at), best|
      estimate = OneRmCalculator.calculate_average(weight_kg, reps)
      next unless estimate
      next if best[lift_key] && best[lift_key][:estimated_1rm_kg] >= estimate

      best[lift_key] = {
        exercise_name: exercise_name,
        estimated_1rm_kg: estimate,
        date: finished_at.to_date.iso8601,
        finished_at: finished_at
      }
    end
  end

  def latest_prior_bodyweight(weights, finished_at)
    measured_at, weight_kg = weights.reverse_each.find do |candidate_time, _candidate_weight|
      candidate_time <= finished_at && candidate_time >= finished_at - MAX_BODYWEIGHT_AGE_DAYS.days
    end
    [ measured_at, weight_kg ]
  end

  def empty_ratios(reason)
    { labels: LIFT_KEYS.map(&:titleize), values: [], details: {}, reason: reason }
  end

  def empty_scores(reason)
    { points: [], reason: reason }
  end
end
