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
    existing_by_key = @user.notifications.where(dedupe_key: keys).index_by(&:dedupe_key)

    candidates.each { |candidate| upsert_notification(candidate, existing_by_key) }
    expire_stale_notifications!(keys)

    @user.notifications.recent.limit(MAX_NOTIFICATIONS)
  end

  private

  def build_candidates
    [ *readiness_candidates, *plateau_candidates, streak_risk_candidate, weekly_volume_drop_candidate ]
      .compact
      .select { |candidate| @user.notification_enabled_for?(candidate[:kind]) }
  end

  def readiness_candidates
    candidates = []

    recent_combos = @user.workouts
      .where.not(finished_at: nil)
      .where('finished_at >= ?', 30.days.ago)
      .joins(:workout_exercises)
      .pluck(Arel.sql('DISTINCT workout_exercises.exercise_id, workout_exercises.machine_id'))
      .first(8)

    exercise_ids = recent_combos.map(&:first).compact.uniq
    machine_ids = recent_combos.map(&:last).compact.uniq
    exercises_by_id = Exercise.where(id: exercise_ids).index_by(&:id)
    machines_by_id = Machine.where(id: machine_ids).index_by(&:id)

    recent_combos.each do |exercise_id, machine_id|
      exercise = exercises_by_id[exercise_id]
      next unless exercise

      machine = machine_id ? machines_by_id[machine_id] : nil
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

    exercise_ids = active_exercises.map(&:first)
    sets_by_exercise = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workout_exercises: { exercise_id: exercise_ids })
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .order(Arel.sql('workout_exercises.exercise_id ASC, workouts.finished_at ASC'))
      .pluck(Arel.sql('workout_exercises.exercise_id'), :weight_kg, Arel.sql('workouts.finished_at'))
      .group_by(&:first)

    active_exercises.each do |exercise_id, exercise_name|
      sets = sets_by_exercise[exercise_id]&.map { |(_, weight, finished_at)| [ weight, finished_at ] } || []

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
    stats = week_to_date_volume_stats
    this_week_volume = stats[:this_week_volume]
    this_week_workouts = stats[:this_week_workouts]
    last_week_volume = stats[:last_week_volume]

    # Avoid noisy "volume down" alerts at the start of a new week
    # before the user has logged any session.
    return nil if this_week_workouts.zero?
    return nil unless last_week_volume.positive?

    ratio = this_week_volume / last_week_volume.to_f
    return nil unless ratio < 0.6

    {
      kind: 'volume_drop',
      severity: 'warning',
      title: 'Weekly Volume Down',
      message: "Week-to-date volume is #{(ratio * 100).round}% of the same point last week. Consider a catch-up session.",
      dedupe_key: "volume-drop:#{Date.current.cwyear}-#{Date.current.cweek}",
      metadata: {
        this_week_volume_kg: this_week_volume.round,
        this_week_workouts: this_week_workouts,
        last_week_volume_kg: last_week_volume.round,
        ratio: ratio.round(2)
      }
    }
  end

  def week_to_date_volume_stats
    today = Date.current
    week_start = today.beginning_of_week
    day_offset = (today - week_start).to_i

    this_week_start = week_start.beginning_of_day
    this_week_end = Time.current
    last_week_start = (week_start - 1.week).beginning_of_day
    last_week_end = (last_week_start.to_date + day_offset.days).end_of_day

    this_week_scope = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: this_week_start..this_week_end)
      .where(exercise_sets: { is_warmup: false })
    last_week_scope = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: last_week_start..last_week_end)
      .where(exercise_sets: { is_warmup: false })

    {
      this_week_volume: this_week_scope.sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)'),
      this_week_workouts: this_week_scope.distinct.count(:id),
      last_week_volume: last_week_scope.sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')
    }
  end

  def upsert_notification(candidate, existing_by_key)
    notification = existing_by_key[candidate[:dedupe_key]] ||
      @user.notifications.build(dedupe_key: candidate[:dedupe_key])
    notification.assign_attributes(
      kind: candidate[:kind],
      severity: candidate[:severity],
      title: candidate[:title],
      message: candidate[:message],
      metadata: candidate[:metadata]
    )
    if notification.changed?
      notification.save!
      existing_by_key[candidate[:dedupe_key]] = notification
    end
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
