# frozen_string_literal: true

# Builds and persists in-app analytics notifications for a user.
# Refresh is idempotent via dedupe_key uniqueness.
class PerformanceNotificationService
  MAX_NOTIFICATIONS = 20
  PERFORMANCE_KINDS = %w[readiness plateau streak_risk volume_drop].freeze

  def initialize(user:)
    @user = user
  end

  def refresh!
    candidates = build_candidates
    keys = candidates.map { |candidate| candidate[:dedupe_key] }

    candidates.each { |candidate| upsert_notification(candidate) }
    expire_stale_notifications!(keys)

    @user.notifications.recent.limit(MAX_NOTIFICATIONS)
  end

  private

  def build_candidates
    [ *readiness_candidates, *plateau_candidates, streak_risk_candidate, weekly_volume_drop_candidate ].compact
  end

  def readiness_candidates
    candidates = []

    recent_combos = @user.workouts
      .where.not(finished_at: nil)
      .where('finished_at >= ?', 30.days.ago)
      .joins(workout_exercises: :exercise)
      .pluck(Arel.sql('DISTINCT exercises.id, workout_exercises.machine_id'))
      .first(8)

    recent_combos.each do |exercise_id, machine_id|
      exercise = Exercise.find_by(id: exercise_id)
      next unless exercise

      machine = machine_id ? Machine.find_by(id: machine_id) : nil
      checker = ProgressionReadinessChecker.new(exercise: exercise, user: @user, machine: machine)
      readiness = checker.check_readiness
      next unless readiness

      candidates << {
        kind: 'readiness',
        severity: 'success',
        title: 'Ready to Progress',
        message: checker.readiness_message,
        dedupe_key: "readiness:#{exercise.id}:#{machine_id}:#{readiness[:sessions_analyzed]}",
        metadata: {
          exercise_id: exercise.id,
          machine_id: machine_id
        }
      }
    end

    candidates
  end

  def plateau_candidates
    candidates = []

    active_exercises = @user.workout_exercises
      .joins(:exercise, :exercise_sets, workout_block: :workout)
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(exercises: { has_weight: true })
      .where(exercise_sets: { is_warmup: false })
      .where.not(exercise_sets: { weight_kg: nil })
      .select(Arel.sql('exercises.id, exercises.name'))
      .distinct
      .pluck(Arel.sql('exercises.id'), Arel.sql('exercises.name'))

    active_exercises.each do |exercise_id, exercise_name|
      sets = @user.exercise_sets
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: exercise_id })
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil)
        .order(Arel.sql('workouts.finished_at ASC'))
        .pluck(:weight_kg, Arel.sql('workouts.finished_at'))

      next if sets.size < 3

      best_weight = 0
      last_pr_date = nil
      sets.each do |weight, finished_at|
        next unless weight && finished_at

        if weight > best_weight
          best_weight = weight
          last_pr_date = finished_at.to_date
        end
      end

      next unless last_pr_date

      weeks_since_pr = ((Date.current - last_pr_date) / 7).to_i
      last_workout_date = sets.last[1]&.to_date
      next unless last_workout_date

      days_since_last_workout = (Date.current - last_workout_date).to_i
      next unless weeks_since_pr >= 4 && days_since_last_workout <= 30

      candidates << {
        kind: 'plateau',
        severity: weeks_since_pr >= 8 ? 'danger' : 'warning',
        title: "#{exercise_name}: Plateau Watch",
        message: "No new weight PR for #{weeks_since_pr} weeks. Best: #{@user.format_weight(best_weight)}#{@user.preferred_unit}.",
        dedupe_key: "plateau:#{exercise_id}:#{last_pr_date.iso8601}",
        metadata: {
          exercise_id: exercise_id,
          weeks_since_pr: weeks_since_pr
        }
      }
    end

    candidates.sort_by { |c| -c.dig(:metadata, :weeks_since_pr).to_i }.first(5)
  end

  def streak_risk_candidate
    last_finished_at = @user.workouts.where.not(finished_at: nil).maximum(:finished_at)
    return nil unless last_finished_at

    days_since = (Date.current - last_finished_at.to_date).to_i
    return nil if days_since < 4

    severity = days_since >= 7 ? 'danger' : 'warning'
    {
      kind: 'streak_risk',
      severity: severity,
      title: 'Consistency Streak At Risk',
      message: "No workout logged in #{days_since} days. A short session today keeps momentum.",
      dedupe_key: "streak-risk:#{Date.current.cwyear}-#{Date.current.cweek}",
      metadata: {
        days_since_last_workout: days_since
      }
    }
  end

  def weekly_volume_drop_candidate
    this_week = week_volume(0)
    last_week = week_volume(1)
    return nil unless last_week.positive?

    ratio = this_week / last_week.to_f
    return nil unless ratio < 0.6

    {
      kind: 'volume_drop',
      severity: 'warning',
      title: 'Weekly Volume Down',
      message: "Current week volume is #{(ratio * 100).round}% of last week. Consider a catch-up session.",
      dedupe_key: "volume-drop:#{Date.current.cwyear}-#{Date.current.cweek}",
      metadata: {
        this_week_volume_kg: this_week.round,
        last_week_volume_kg: last_week.round,
        ratio: ratio.round(2)
      }
    }
  end

  def week_volume(weeks_ago)
    week_start = weeks_ago.weeks.ago.beginning_of_week
    week_end = weeks_ago.weeks.ago.end_of_week

    @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: week_start..week_end)
      .where(exercise_sets: { is_warmup: false })
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')
      .to_f
  end

  def upsert_notification(candidate)
    notification = @user.notifications.find_or_initialize_by(dedupe_key: candidate[:dedupe_key])
    notification.assign_attributes(
      kind: candidate[:kind],
      severity: candidate[:severity],
      title: candidate[:title],
      message: candidate[:message],
      metadata: candidate[:metadata]
    )
    notification.save! if notification.changed?
  end

  def expire_stale_notifications!(active_keys)
    # Keep read history, clean only stale unread performance notifications
    @user.notifications
      .where(kind: PERFORMANCE_KINDS)
      .where(read_at: nil)
      .where.not(dedupe_key: active_keys)
      .where('created_at < ?', 6.hours.ago)
      .delete_all
  end
end
