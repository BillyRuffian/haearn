# frozen_string_literal: true

# Encapsulates cached dashboard analytics calculations so controllers stay
# focused on request orchestration and rendering.
class DashboardAnalyticsCalculator
  DURATION_MINUTES_SQL = '(julianday(workouts.finished_at) - julianday(workouts.started_at)) * 1440.0'.freeze
  ROUNDED_DURATION_MINUTES_SQL = 'ROUND((julianday(workouts.finished_at) - julianday(workouts.started_at)) * 1440.0)'.freeze
  MINIMUM_DURATION_SQL = '((julianday(workouts.finished_at) - julianday(workouts.started_at)) * 1440.0) >= 5'.freeze

  KEY_METHODS = {
    'pr_timeline' => :pr_timeline,
    'consistency' => :consistency_data,
    'rep_range_distribution' => :rep_range_distribution,
    'workout_frequency' => :workout_frequency,
    'exercise_frequency' => :exercise_frequency,
    'streaks' => :streaks,
    'week_comparison' => :week_comparison,
    'tonnage' => :tonnage_tracker,
    'training_period_totals' => :training_period_totals,
    'plateaus' => :plateaus,
    'training_density' => :training_density,
    'muscle_group_volume' => :muscle_group_volume,
    'muscle_balance' => :muscle_balance,
    'muscle_volume_distribution' => :muscle_volume_distribution,
    'strength_curves' => :strength_curves,
    'lift_ratios' => :lift_ratios,
    'strength_score_trend' => :strength_score_trend
  }.freeze

  def initialize(user:)
    @user = user
  end

  def calculate(key)
    public_send(KEY_METHODS.fetch(key))
  end

  def rep_range_distribution
    buckets = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at >= ?', 30.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(reps: nil)
      .group(Arel.sql(<<~SQL.squish))
        CASE
          WHEN exercise_sets.reps BETWEEN 1 AND 5 THEN '1-5'
          WHEN exercise_sets.reps BETWEEN 6 AND 10 THEN '6-10'
          WHEN exercise_sets.reps BETWEEN 11 AND 15 THEN '11-15'
          ELSE '16+'
        END
      SQL
      .count

    [ '1-5', '6-10', '11-15', '16+' ].index_with { |bucket| buckets.fetch(bucket, 0) }
  end

  def workout_frequency
    weekly_counts(weeks: 8).map { |week| week.slice(:label, :count) }
  end

  def exercise_frequency
    @user.workout_exercises
      .joins(:exercise, :exercise_sets, workout_block: :workout)
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .group(Arel.sql('exercises.name'))
      .order(Arel.sql('COUNT(DISTINCT workout_exercises.id) DESC'))
      .limit(10)
      .count(Arel.sql('DISTINCT workout_exercises.id'))
      .map { |name, count| { exercise: name, count: count } }
  end

  def pr_timeline
    prs = []
    since = 12.months.ago
    recent_sets = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .left_joins(workout_exercise: :machine)
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(exercises: { has_weight: true })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .where('exercise_sets.reps > 0')
      .pluck(
        Arel.sql('workout_exercises.exercise_id'),
        Arel.sql('workout_exercises.machine_id'),
        Arel.sql('exercises.name'),
        Arel.sql('machines.name'),
        :weight_kg,
        :reps,
        :completed_at,
        :created_at
      )

    historical_weights = historical_best_weights(since:)
    historical_volumes = historical_best_volumes(since:)

    recent_sets.group_by { |exercise_id, machine_id, *| [ exercise_id, machine_id ] }.each do |combo, sets_for_combo|
      exercise_name = sets_for_combo.first[2]
      machine_name = sets_for_combo.first[3]
      context_label = machine_name ? "#{exercise_name} — #{machine_name}" : "#{exercise_name} — No equipment"
      all_sets = sets_for_combo.sort_by { |row| row[6] || row[7] }

      next if all_sets.empty?

      best_weight = historical_weights.fetch(combo, 0)
      best_volume = historical_volumes.fetch(combo, 0)
      has_previous_set = best_weight.positive? || best_volume.positive?

      all_sets.each do |_exercise_id, machine_id, _name, _machine_name, weight, reps, completed_at, created_at|
        date = (completed_at || created_at).to_date
        volume = weight * reps
        common = {
          exercise: exercise_name,
          context: context_label,
          machine_id: machine_id,
          date: date.to_s,
          weight: @user.display_weight(weight).round(2),
          reps: reps,
          set_load_volume: display_volume(volume)
        }

        prs << common.merge(type: 'weight') if weight > best_weight && has_previous_set
        best_weight = weight if weight > best_weight

        prs << common.merge(type: 'volume') if volume > best_volume && has_previous_set
        best_volume = volume if volume > best_volume
        has_previous_set = true
      end
    end

    prs.sort_by { |pr| pr[:date] }.last(100)
  end

  def streaks
    workout_dates = @user.workouts
      .where.not(finished_at: nil)
      .distinct
      .order(Arel.sql('DATE(finished_at) DESC'))
      .pluck(Arel.sql('DATE(finished_at)'))
      .map { |date| Date.iso8601(date) }

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
    this_week_start = Time.current.beginning_of_week
    elapsed = Time.current - this_week_start
    last_week_start = this_week_start - 1.week
    this_week_range = this_week_start..Time.current
    last_week_range = last_week_start..(last_week_start + elapsed)
    totals = comparison_totals(this_week: this_week_range, last_week: last_week_range)

    {
      this_week: {
        volume: display_volume(totals['this_week_volume']),
        workouts: totals['this_week_workouts'].to_i,
        sets: totals['this_week_sets'].to_i,
        range_label: compact_range_label(this_week_range)
      },
      last_week: {
        volume: display_volume(totals['last_week_volume']),
        workouts: totals['last_week_workouts'].to_i,
        sets: totals['last_week_sets'].to_i,
        range_label: compact_range_label(last_week_range)
      }
    }
  end

  def tonnage_tracker
    weekly_volume = @user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: 11.weeks.ago.beginning_of_week..Time.current.end_of_week)
      .where(exercise_sets: { is_warmup: false })
      .group(Arel.sql(week_bucket_sql('workouts.finished_at')))
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    week_starts(12).map do |week_start|
      { label: week_start.strftime('%b %d'), volume: display_volume(weekly_volume.fetch(week_start.iso8601, 0)) }
    end
  end

  def training_period_totals
    today = Date.current
    workout_bounds = @user.workouts.where.not(finished_at: nil).pick(Arel.sql('MIN(finished_at)'), Arel.sql('MAX(finished_at)'))
    all_time_start = workout_bounds&.first&.to_date
    all_time_end = workout_bounds&.last&.to_date
    periods = [
      { label: 'This week', start_date: today.beginning_of_week, end_date: today },
      { label: 'Last 30 days', start_date: 29.days.ago.to_date, end_date: today },
      { label: 'Last 90 days', start_date: 89.days.ago.to_date, end_date: today },
      { label: 'Last 12 months', start_date: 12.months.ago.to_date, end_date: today },
      { label: 'All time', start_date: all_time_start, end_date: all_time_end }
    ].map do |period|
      start_date = clamped_start_date(period[:start_date], all_time_start)
      period.merge(start_date: start_date)
    end

    volumes = period_volume_totals(periods)
    durations = period_duration_totals(periods)

    periods.each_with_index.map do |period, index|
      start_date = period[:start_date]
      end_date = period[:end_date]
      volume = volumes.fetch("period_#{index}", 0).to_f
      duration_minutes = durations.fetch("period_#{index}", 0).to_f.round

      {
        label: period[:label],
        volume: display_volume(volume),
        duration_minutes: duration_minutes,
        duration_label: duration_label(duration_minutes),
        start_date: start_date&.iso8601,
        end_date: end_date&.iso8601,
        range_label: range_label(start_date, end_date)
      }
    end
  end

  def plateaus
    active_exercise_ids = @user.workout_exercises
      .joins(:exercise_sets, workout_block: :workout)
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(exercise_sets: { is_warmup: false })
      .where.not(exercise_sets: { weight_kg: nil })
      .distinct
      .select(:exercise_id)

    set_rows = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where.not(workouts: { finished_at: nil })
      .where(exercises: { has_weight: true })
      .where(workout_exercises: { exercise_id: active_exercise_ids })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .order(Arel.sql('workout_exercises.exercise_id ASC, workouts.finished_at ASC'))
      .pluck(
        Arel.sql('workout_exercises.exercise_id'),
        Arel.sql('exercises.name'),
        :weight_kg,
        Arel.sql('workouts.finished_at')
      )

    set_rows.group_by(&:first).filter_map do |_exercise_id, all_sets|
      exercise_name = all_sets.first[1]

      next if all_sets.length < 3

      best_weight = 0
      last_pr_date = nil

      all_sets.each do |_id, _name, weight, finished_at|
        next unless weight > best_weight

        best_weight = weight
        last_pr_date = finished_at.to_date
      end

      next unless last_pr_date

      weeks_since_pr = ((Date.current - last_pr_date) / 7).to_i
      last_workout_date = all_sets.last[3].to_date
      days_since_last_workout = (Date.current - last_workout_date).to_i

      if weeks_since_pr >= 4 && days_since_last_workout <= 30
        {
          exercise: exercise_name,
          weeks_since_pr: weeks_since_pr,
          best_weight: @user.display_weight(best_weight).round,
          last_pr_date: last_pr_date.strftime('%b %d')
        }
      end
    end.sort_by { |plateau| -plateau[:weeks_since_pr] }.first(5)
  end

  def training_density
    volume_sql = working_volume_sql
    rows = @user.workouts
      .left_joins(workout_exercises: :exercise_sets)
      .left_joins(:gym)
      .where.not(finished_at: nil)
      .where.not(started_at: nil)
      .group('workouts.id', 'gyms.name')
      .having(Arel.sql(MINIMUM_DURATION_SQL))
      .order(finished_at: :desc)
      .limit(20)
      .pluck(
        :finished_at,
        Arel.sql(ROUNDED_DURATION_MINUTES_SQL),
        Arel.sql(volume_sql),
        Arel.sql('gyms.name')
      )

    rows.map do |finished_at, duration_minutes, volume, gym_name|
      display_volume = display_volume(volume)

      {
        date: finished_at.to_date.to_s,
        density: (display_volume / duration_minutes.to_f).round,
        volume: display_volume,
        duration: duration_minutes.to_i,
        gym: gym_name || 'Unknown'
      }
    end.reverse
  end

  def muscle_group_volume
    stats = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where('workouts.finished_at >= ?', 7.days.ago.beginning_of_day)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })
      .where(is_warmup: false)
      .group(Arel.sql('exercises.primary_muscle_group'))
      .pluck(
        Arel.sql('exercises.primary_muscle_group'),
        Arel.sql('SUM(COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0))'),
        Arel.sql('COUNT(exercise_sets.id)'),
        Arel.sql('MAX(workouts.finished_at)')
      )

    stats.each_with_object({}) do |(muscle, volume, sets, last_trained), result|
      result[muscle] = {
        volume: display_volume(volume),
        sets: sets,
        days_since: last_trained ? (Date.current - time_value(last_trained).to_date).to_i : 999,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle] || '#71797E'
      }
    end
  end

  def consistency_data
    twelve_weeks = weekly_counts(weeks: 12)

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
    muscle_volumes = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where('workouts.finished_at >= ?', 30.days.ago.beginning_of_day)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })
      .where(is_warmup: false)
      .group(Arel.sql('exercises.primary_muscle_group'))
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')

    total_volume = muscle_volumes.values.sum.to_f

    Exercise::MUSCLE_GROUPS.filter_map do |muscle|
      raw_volume = (muscle_volumes[muscle] || 0).round
      next if raw_volume.zero?

      {
        muscle: Exercise::MUSCLE_GROUP_LABELS[muscle],
        value: total_volume.positive? ? (((muscle_volumes[muscle] || 0) / total_volume) * 100).round(1) : 0,
        raw_volume: raw_volume,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle]
      }
    end
  end

  def muscle_volume_distribution
    today = Date.current
    seven_days_start = 6.days.ago.beginning_of_day
    thirty_days_start = 29.days.ago.beginning_of_day
    seven_condition = "workouts.finished_at >= #{connection.quote(seven_days_start)}"

    rows = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where(workouts: { finished_at: thirty_days_start..Time.current })
      .where(is_warmup: false)
      .where.not(exercises: { primary_muscle_group: nil })
      .group(Arel.sql('exercises.primary_muscle_group'))
      .pluck(
        Arel.sql('exercises.primary_muscle_group'),
        Arel.sql("COALESCE(SUM(CASE WHEN #{seven_condition} THEN COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0) ELSE 0 END), 0)"),
        Arel.sql('COALESCE(SUM(COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)), 0)')
      )

    seven_days = {}
    thirty_days = {}
    rows.each do |muscle, seven_volume, thirty_volume|
      seven_days[muscle] = display_volume(seven_volume) if seven_volume.to_d.positive?
      thirty_days[muscle] = display_volume(thirty_volume) if thirty_volume.to_d.positive?
    end

    {
      seven_days: seven_days,
      thirty_days: thirty_days,
      labels: Exercise::MUSCLE_GROUP_LABELS,
      colors: Exercise::MUSCLE_GROUP_COLORS,
      seven_days_start: seven_days_start.to_date.iso8601,
      thirty_days_start: thirty_days_start.to_date.iso8601,
      end_date: today.iso8601
    }
  end

  def strength_curves
    rows = @user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .left_joins(workout_exercise: :machine)
      .where('workouts.finished_at >= ?', 12.months.ago)
      .where.not(workouts: { finished_at: nil })
      .where(exercises: { has_weight: true })
      .where(is_warmup: false)
      .where.not(weight_kg: nil, reps: nil)
      .where('exercise_sets.reps BETWEEN 1 AND 15')
      .group(Arel.sql('workout_exercises.exercise_id'), Arel.sql('workout_exercises.machine_id'), Arel.sql('exercises.name'), Arel.sql('machines.name'))
      .order(Arel.sql('MAX(workouts.finished_at) DESC, exercises.name ASC, workout_exercises.machine_id ASC'))
      .limit(5)
      .pluck(
        Arel.sql('workout_exercises.exercise_id'), Arel.sql('workout_exercises.machine_id'), Arel.sql('exercises.name'), Arel.sql('machines.name'),
        Arel.sql('MAX(CASE WHEN exercise_sets.reps BETWEEN 1 AND 3 THEN exercise_sets.weight_kg END)'),
        Arel.sql('MAX(CASE WHEN exercise_sets.reps BETWEEN 4 AND 6 THEN exercise_sets.weight_kg END)'),
        Arel.sql('MAX(CASE WHEN exercise_sets.reps BETWEEN 7 AND 10 THEN exercise_sets.weight_kg END)'),
        Arel.sql('MAX(CASE WHEN exercise_sets.reps BETWEEN 11 AND 15 THEN exercise_sets.weight_kg END)')
      )

    rows.map do |exercise_id, machine_id, exercise_name, machine_name, one_to_three, four_to_six, seven_to_ten, eleven_to_fifteen|
      machine_label = machine_id ? machine_name : 'No equipment'
      {
        exercise_id: exercise_id,
        machine_id: machine_id,
        name: "#{exercise_name} — #{machine_label}",
        ranges: {
          '1-3' => one_to_three && @user.display_weight(one_to_three).round(2),
          '4-6' => four_to_six && @user.display_weight(four_to_six).round(2),
          '7-10' => seven_to_ten && @user.display_weight(seven_to_ten).round(2),
          '11-15' => eleven_to_fifteen && @user.display_weight(eleven_to_fifteen).round(2)
        }
      }
    end
  end

  def lift_ratios
    strength_analytics.lift_ratios
  end

  def strength_score_trend
    strength_analytics.score_trend
  end

  private

  def strength_analytics
    @strength_analytics ||= StrengthAnalyticsCalculator.new(user: @user)
  end

  def historical_best_weights(since:)
    @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at < ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .group(Arel.sql('workout_exercises.exercise_id'), Arel.sql('workout_exercises.machine_id'))
      .maximum(:weight_kg)
  end

  def historical_best_volumes(since:)
    rows = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at < ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil, reps: nil)
      .where('exercise_sets.reps > 0')
      .group(Arel.sql('workout_exercises.exercise_id'), Arel.sql('workout_exercises.machine_id'))
      .pluck(
        Arel.sql('workout_exercises.exercise_id'),
        Arel.sql('workout_exercises.machine_id'),
        Arel.sql('MAX(exercise_sets.weight_kg * exercise_sets.reps)')
      )

    rows.to_h { |exercise_id, machine_id, volume| [ [ exercise_id, machine_id ], volume ] }
  end

  def weekly_counts(weeks:)
    counts = @user.workouts
      .where(finished_at: (weeks - 1).weeks.ago.beginning_of_week..Time.current.end_of_week)
      .group(Arel.sql(week_bucket_sql('workouts.finished_at')))
      .count

    week_starts(weeks).map do |week_start|
      {
        label: week_start.strftime('%b %d'),
        week_start: week_start.strftime('%b %d'),
        count: counts.fetch(week_start.iso8601, 0)
      }
    end
  end

  def week_starts(number_of_weeks)
    (number_of_weeks - 1).downto(0).map { |weeks_ago| weeks_ago.weeks.ago.beginning_of_week.to_date }
  end

  def week_bucket_sql(column)
    "DATE(#{column}, 'weekday 0', '-6 days')"
  end

  def comparison_totals(periods)
    selections = periods.flat_map do |name, range|
      condition = range_condition('workouts.finished_at', range.begin, range.end)
      working_condition = "#{condition} AND exercise_sets.is_warmup = #{connection.quote(false)}"

      [
        "COALESCE(SUM(CASE WHEN #{working_condition} THEN COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0) ELSE 0 END), 0) AS #{name}_volume",
        "COUNT(DISTINCT CASE WHEN #{condition} THEN workouts.id END) AS #{name}_workouts",
        "COUNT(CASE WHEN #{working_condition} THEN exercise_sets.id END) AS #{name}_sets"
      ]
    end

    range_start = periods.values.map(&:begin).min.beginning_of_day
    range_end = periods.values.map(&:end).max.end_of_day
    relation = @user.workouts
      .left_joins(workout_exercises: :exercise_sets)
      .where(finished_at: range_start..range_end)

    select_row(relation, selections)
  end

  def period_volume_totals(periods)
    relation = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(is_warmup: false)
    period_aggregates(relation, periods, 'exercise_sets.weight_kg * exercise_sets.reps')
  end

  def period_duration_totals(periods)
    relation = @user.workouts.where.not(started_at: nil, finished_at: nil)
    period_aggregates(relation, periods, ROUNDED_DURATION_MINUTES_SQL)
  end

  def period_aggregates(relation, periods, expression)
    selections = periods.each_with_index.map do |period, index|
      condition = period_condition(period)
      "COALESCE(SUM(CASE WHEN #{condition} THEN #{expression} ELSE 0 END), 0) AS period_#{index}"
    end

    select_row(relation, selections)
  end

  def period_condition(period)
    return '0 = 1' unless period[:start_date] && period[:end_date]

    range_condition('workouts.finished_at', period[:start_date], period[:end_date])
  end

  def range_condition(column, start_value, end_value)
    start_time = start_value.respond_to?(:beginning_of_day) ? start_value.beginning_of_day : start_value
    end_time = end_value.respond_to?(:end_of_day) ? end_value.end_of_day : end_value
    "#{column} >= #{connection.quote(start_time)} AND #{column} <= #{connection.quote(end_time)}"
  end

  def select_row(relation, selections)
    connection.select_one(relation.select(Arel.sql(selections.join(', '))).to_sql) || {}
  end

  def working_volume_sql
    <<~SQL.squish
      COALESCE(SUM(CASE WHEN exercise_sets.is_warmup = #{connection.quote(false)}
        THEN COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)
        ELSE 0 END), 0)
    SQL
  end

  def time_value(value)
    value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
  end

  def connection
    ActiveRecord::Base.connection
  end

  def display_volume(volume)
    if @user.preferred_unit == 'lbs'
      (volume * 2.20462).round
    else
      volume.round
    end
  end

  def clamped_start_date(start_date, first_workout_date)
    return start_date unless start_date && first_workout_date

    [ start_date, first_workout_date ].max
  end

  def range_label(start_date, end_date)
    return 'No completed workouts yet' unless start_date && end_date

    "#{format_date(start_date)} - #{format_date(end_date)}"
  end

  def format_date(date)
    date.strftime('%b %-d, %Y')
  end

  def compact_range_label(range)
    "#{range.begin.to_date.strftime('%b %-d')}–#{range.end.to_date.strftime('%b %-d')}"
  end

  def duration_label(minutes)
    hours = minutes / 60
    remaining_minutes = minutes % 60

    if hours.positive? && remaining_minutes.positive?
      "#{hours}h #{remaining_minutes}m"
    elsif hours.positive?
      "#{hours}h"
    else
      "#{remaining_minutes}m"
    end
  end
end
