# frozen_string_literal: true

# Encapsulates cached dashboard analytics calculations so controllers stay
# focused on request orchestration and rendering.
class DashboardAnalyticsCalculator
  KEY_METHODS = {
    'pr_timeline' => :pr_timeline,
    'consistency' => :consistency_data,
    'rep_range_distribution' => :rep_range_distribution,
    'exercise_frequency' => :exercise_frequency,
    'streaks' => :streaks,
    'week_comparison' => :week_comparison,
    'tonnage' => :tonnage_tracker,
    'plateaus' => :plateaus,
    'training_density' => :training_density,
    'muscle_group_volume' => :muscle_group_volume,
    'muscle_balance' => :muscle_balance
  }.freeze

  def initialize(user:)
    @user = user
  end

  def calculate(key)
    public_send(KEY_METHODS.fetch(key))
  end

  def rep_range_distribution
    sets = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at >= ?', 30.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(reps: nil)
      .pluck(:reps)

    {
      '1-5' => sets.count { |reps| reps.between?(1, 5) },
      '6-10' => sets.count { |reps| reps.between?(6, 10) },
      '11-15' => sets.count { |reps| reps.between?(11, 15) },
      '16+' => sets.count { |reps| reps >= 16 }
    }
  end

  def exercise_frequency
    @user.workout_exercises
      .joins(:exercise, workout_block: :workout)
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .group(Arel.sql('exercises.name'))
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .map { |name, count| { exercise: name, count: count } }
  end

  def pr_timeline
    prs = []
    since = 12.months.ago

    workout_exercises = @user.workout_exercises
      .joins(workout_block: :workout)
      .includes(:exercise, :machine, :exercise_sets)
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })

    workout_exercises.group_by { |workout_exercise| [ workout_exercise.exercise_id, workout_exercise.machine_id ] }.each do |(exercise_id, machine_id), workout_exercises_for_combo|
      exercise = workout_exercises_for_combo.first.exercise
      next unless exercise&.has_weight?

      historical_best_weight = @user.exercise_sets
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: exercise_id, machine_id: machine_id })
        .where('workouts.finished_at < ?', since)
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil)
        .maximum(:weight_kg) || 0

      historical_best_volume = historical_best_volume(exercise_id:, machine_id:, since:)
      all_sets = workout_exercises_for_combo.flat_map do |workout_exercise|
        workout_exercise.exercise_sets.select { |set| !set.is_warmup && set.weight_kg.present? && set.reps&.positive? }
      end.sort_by { |set| set.completed_at || set.created_at }

      next if all_sets.empty?

      best_weight = historical_best_weight
      best_volume = historical_best_volume
      has_previous_set = historical_best_weight > 0 || historical_best_volume > 0

      all_sets.each do |set|
        date = (set.completed_at || set.created_at).to_date
        weight = set.weight_kg
        volume = (set.weight_kg || 0) * (set.reps || 0)

        if weight > best_weight && has_previous_set
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: @user.display_weight(weight).round,
            reps: set.reps || 0,
            type: 'weight'
          }
        end
        best_weight = weight if weight > best_weight

        if volume > best_volume && has_previous_set
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: @user.display_weight(set.weight_kg).round,
            reps: set.reps || 0,
            type: 'volume'
          }
        end
        best_volume = volume if volume > best_volume
        has_previous_set = true
      end
    end

    prs.sort_by { |pr| pr[:date] }.last(100)
  end

  def streaks
    workout_dates = @user.workouts
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .pluck(:finished_at)
      .map(&:to_date)
      .uniq

    return { current: 0, longest: 0, last_workout_days_ago: nil } if workout_dates.empty?

    current_streak = 0
    today = Date.current
    current_week = today.beginning_of_week

    (0..52).map { |index| (today - index.weeks).beginning_of_week }.each do |week_start|
      week_end = week_start.end_of_week
      has_workout = workout_dates.any? { |date| date >= week_start && date <= week_end }

      if has_workout
        current_streak += 1
      else
        break if current_streak > 0 || week_start < current_week
      end
    end

    longest_streak = 0
    temporary_streak = 0
    all_weeks = workout_dates.map(&:beginning_of_week).uniq.sort.reverse

    all_weeks.each_with_index do |week, index|
      if index.zero?
        temporary_streak = 1
      else
        previous_week = all_weeks[index - 1]
        if (previous_week - week).to_i == 7
          temporary_streak += 1
        else
          longest_streak = [ longest_streak, temporary_streak ].max
          temporary_streak = 1
        end
      end
    end
    longest_streak = [ longest_streak, temporary_streak ].max

    {
      current: current_streak,
      longest: longest_streak,
      last_workout_days_ago: (today - workout_dates.first).to_i
    }
  end

  def week_comparison
    this_week_start = Date.current.beginning_of_week
    last_week_start = (Date.current - 1.week).beginning_of_week

    this_week_volume = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: this_week_start..this_week_start.end_of_week)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    last_week_volume = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: last_week_start..last_week_start.end_of_week)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    {
      this_week: {
        volume: display_volume(this_week_volume),
        workouts: @user.workouts.where(finished_at: this_week_start..this_week_start.end_of_week).count,
        sets: sets_count_for(this_week_start..this_week_start.end_of_week)
      },
      last_week: {
        volume: display_volume(last_week_volume),
        workouts: @user.workouts.where(finished_at: last_week_start..last_week_start.end_of_week).count,
        sets: sets_count_for(last_week_start..last_week_start.end_of_week)
      }
    }
  end

  def tonnage_tracker
    (0..11).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      week_end = weeks_ago.weeks.ago.end_of_week
      volume = @user.workouts
        .joins(workout_exercises: :exercise_sets)
        .where(finished_at: week_start..week_end)
        .where(exercise_sets: { is_warmup: false })
        .sum('exercise_sets.weight_kg * exercise_sets.reps')

      {
        label: week_start.strftime('%b %d'),
        volume: display_volume(volume)
      }
    end.reverse
  end

  def plateaus
    plateaus = []

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
      all_sets = @user.exercise_sets
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: exercise_id })
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil)
        .order(Arel.sql('workouts.finished_at ASC'))
        .pluck(:weight_kg, :reps, Arel.sql('workouts.finished_at'))

      next if all_sets.length < 3

      best_weight = 0
      last_pr_date = nil

      all_sets.each do |weight, _reps, finished_at|
        next unless weight > best_weight

        best_weight = weight
        last_pr_date = finished_at.to_date
      end

      next unless last_pr_date

      weeks_since_pr = ((Date.current - last_pr_date) / 7).to_i
      last_workout_date = all_sets.last[2].to_date
      days_since_last_workout = (Date.current - last_workout_date).to_i

      if weeks_since_pr >= 4 && days_since_last_workout <= 30
        plateaus << {
          exercise: exercise_name,
          weeks_since_pr: weeks_since_pr,
          best_weight: @user.display_weight(best_weight).round,
          last_pr_date: last_pr_date.strftime('%b %d')
        }
      end
    end

    plateaus.sort_by { |plateau| -plateau[:weeks_since_pr] }.first(5)
  end

  def training_density
    workouts = @user.workouts
      .where.not(finished_at: nil)
      .where.not(started_at: nil)
      .order(finished_at: :desc)
      .limit(20)

    workouts.filter_map do |workout|
      duration_minutes = workout.duration_minutes || 0
      next if duration_minutes < 5

      volume = workout.exercise_sets
        .where(is_warmup: false)
        .sum('COALESCE(weight_kg, 0) * COALESCE(reps, 0)')
      display_volume = display_volume(volume)

      {
        date: workout.finished_at.to_date.to_s,
        density: (display_volume / duration_minutes.to_f).round,
        volume: display_volume,
        duration: duration_minutes,
        gym: workout.gym&.name || 'Unknown'
      }
    end.reverse
  end

  def muscle_group_volume
    workout_exercises = @user.workout_exercises
      .joins(:exercise, workout_block: :workout)
      .includes(:exercise_sets)
      .where('workouts.finished_at >= ?', 7.days.ago.beginning_of_day)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })

    muscle_stats = {}

    workout_exercises.each do |workout_exercise|
      muscle = workout_exercise.exercise.primary_muscle_group
      next unless muscle

      muscle_stats[muscle] ||= { volume: 0, sets: 0, last_trained: nil }
      volume = workout_exercise.exercise_sets.where(is_warmup: false).sum do |set|
        (set.weight_kg || 0) * (set.reps || 0)
      end

      muscle_stats[muscle][:volume] += volume
      muscle_stats[muscle][:sets] += workout_exercise.exercise_sets.where(is_warmup: false).count

      workout_date = workout_exercise.workout_block.workout.finished_at
      if muscle_stats[muscle][:last_trained].nil? || workout_date > muscle_stats[muscle][:last_trained]
        muscle_stats[muscle][:last_trained] = workout_date
      end
    end

    muscle_stats.each_with_object({}) do |(muscle, stats), result|
      result[muscle] = {
        volume: display_volume(stats[:volume]),
        sets: stats[:sets],
        days_since: stats[:last_trained] ? ((Time.current - stats[:last_trained]) / 1.day).round : 999,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle] || '#71797E'
      }
    end
  end

  def consistency_data
    twelve_weeks = (0..11).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      week_end = weeks_ago.weeks.ago.end_of_week
      {
        week_start: week_start.strftime('%b %d'),
        count: @user.workouts.where(finished_at: week_start..week_end).count
      }
    end.reverse

    day_pattern = @user.workouts
      .where('finished_at >= ?', 90.days.ago)
      .where.not(finished_at: nil)
      .group(Arel.sql("strftime('%w', finished_at)"))
      .count

    days_ordered = [ 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' ]
    day_counts = days_ordered.map.with_index do |day, index|
      database_day = (index + 1) % 7
      { day: day, count: day_pattern[database_day.to_s] || 0 }
    end

    month_workouts = @user.workouts
      .where(finished_at: Time.current.beginning_of_month..Time.current.end_of_month)
      .where.not(finished_at: nil)
      .group(Arel.sql('DATE(finished_at)'))
      .count
      .transform_keys(&:to_s)

    {
      twelve_weeks: twelve_weeks,
      day_pattern: day_counts,
      current_month: month_workouts,
      month_name: Time.current.strftime('%B %Y')
    }
  end

  def muscle_balance
    workout_exercises = @user.workout_exercises
      .joins(:exercise, workout_block: :workout)
      .includes(:exercise_sets)
      .where('workouts.finished_at >= ?', 30.days.ago.beginning_of_day)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })

    muscle_volumes = {}

    workout_exercises.each do |workout_exercise|
      muscle = workout_exercise.exercise.primary_muscle_group
      next unless muscle

      muscle_volumes[muscle] ||= 0
      muscle_volumes[muscle] += workout_exercise.exercise_sets.where(is_warmup: false).sum do |set|
        (set.weight_kg || 0) * (set.reps || 0)
      end
    end

    max_volume = muscle_volumes.values.max || 1

    Exercise::MUSCLE_GROUPS.map do |muscle|
      raw_volume = (muscle_volumes[muscle] || 0).round
      {
        muscle: Exercise::MUSCLE_GROUP_LABELS[muscle],
        value: (((muscle_volumes[muscle] || 0) / max_volume.to_f) * 100).round,
        raw_volume: raw_volume,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle]
      }
    end
  end

  private

  def historical_best_volume(exercise_id:, machine_id:, since:)
    best_volume = 0

    @user.workout_exercises
      .joins(workout_block: :workout)
      .includes(:exercise_sets)
      .where(exercise_id: exercise_id, machine_id: machine_id)
      .where('workouts.finished_at < ?', since)
      .where.not(workouts: { finished_at: nil })
      .each do |workout_exercise|
        volume = workout_exercise.exercise_sets
          .select { |set| !set.is_warmup && set.weight_kg.present? && set.reps&.positive? }
          .sum { |set| (set.weight_kg || 0) * (set.reps || 0) }
        best_volume = volume if volume > best_volume
      end

    best_volume
  end

  def display_volume(volume)
    if @user.preferred_unit == 'lbs'
      (volume * 2.20462).round
    else
      volume.round
    end
  end

  def sets_count_for(finished_at_range)
    @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { finished_at: finished_at_range })
      .where(is_warmup: false)
      .count
  end
end
