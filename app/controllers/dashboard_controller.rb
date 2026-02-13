# Displays the main dashboard with workout statistics, charts, and analytics
# Shows workout frequency, volume tracking, PR timeline, heatmaps, and more
class DashboardController < ApplicationController
  # GET /dashboard
  # Main dashboard view with comprehensive workout analytics
  def index
    return unless Current.user
    load_dashboard_data
  end

  # GET /analytics
  # Dedicated analytics page containing all training charts and trends
  def analytics
    return unless Current.user
    load_dashboard_data
  end

  private

  def load_dashboard_data
    # Stats for dashboard
    # Quick stats for the top of dashboard
    @workouts_this_week = Current.user.workouts
      .where(finished_at: 1.week.ago.beginning_of_day..Time.current)
      .count

    # Total volume (weight × reps) for working sets this week
    @volume_this_week = Current.user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: 1.week.ago.beginning_of_day..Time.current)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    # Convert volume to user's preferred unit
    if Current.user.preferred_unit == 'lbs'
      @volume_this_week = (@volume_this_week * 2.20462).round
    else
      @volume_this_week = @volume_this_week.round
    end

    # PR Timeline data (last 12 months of PRs across all exercises)
    @pr_timeline_data = cached_analytics('pr_timeline') { calculate_pr_timeline }

    # PRs this month (count from timeline data)
    start_of_month = Time.current.beginning_of_month.to_date.to_s
    @prs_this_month = @pr_timeline_data.count { |pr| pr[:date] >= start_of_month }

    # Current bodyweight (most recent entry)
    @current_weight_kg = Current.user.body_metrics.current_weight_kg

    # Recent workouts (last 5 completed)
    @recent_workouts = Current.user.workouts
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .limit(5)

    # Pinned workout templates for quick access
    @pinned_templates = Current.user.workout_templates
      .pinned
      .includes(template_blocks: :template_exercises)

    # Fatigue Analysis (active workout only)
    @fatigue_data = []
    if Current.user.active_workout
      Current.user.active_workout.workout_exercises.includes(:exercise, :machine).each do |we|
        next if we.exercise_sets.working.empty? # Skip if no working sets yet

        analyzer = FatigueAnalyzer.new(workout_exercise: we, user: Current.user)
        analysis = analyzer.analyze
        next unless analysis # Skip if insufficient data

        @fatigue_data << {
          workout_exercise: we,
          analysis: analysis,
          message: analyzer.status_message,
          color: analyzer.status_color
        }
      end
    end

    # Progression Readiness Checks (all recently trained exercises)
    @readiness_alerts = []
    recent_exercise_machine_combos = Current.user.workouts
      .where.not(finished_at: nil)
      .where('finished_at >= ?', 30.days.ago)
      .joins(:workout_exercises)
      .pluck(Arel.sql('DISTINCT workout_exercises.exercise_id, workout_exercises.machine_id'))
      .first(10) # Limit to 10 most recent exercise combinations

    exercise_ids = recent_exercise_machine_combos.map(&:first).compact.uniq
    machine_ids = recent_exercise_machine_combos.map(&:last).compact.uniq
    exercises_by_id = Exercise.where(id: exercise_ids).index_by(&:id)
    machines_by_id = Machine.where(id: machine_ids).index_by(&:id)

    recent_exercise_machine_combos.each do |exercise_id, machine_id|
      exercise = exercises_by_id[exercise_id]
      next unless exercise

      machine = machine_id ? machines_by_id[machine_id] : nil

      checker = ProgressionReadinessChecker.new(
        exercise: exercise,
        user: Current.user,
        machine: machine
      )

      readiness = checker.check_readiness
      next unless readiness

      @readiness_alerts << {
        exercise: exercise,
        machine: machine,
        readiness: readiness,
        message: checker.readiness_message
      }
    end

    # Workout frequency data for chart (last 8 weeks)
    frequency_counts = weekly_workout_counts(week_count: 8)
    @workout_frequency = build_weekly_series(week_count: 8) do |week_start|
      {
        label: week_start.strftime('%b %d'),
        count: frequency_counts[week_bucket_key(week_start)] || 0
      }
    end

    # Consistency data for compact visualization
    @consistency_data = cached_analytics('consistency') { calculate_consistency_data }

    # Rep range distribution (last 30 days)
    @rep_range_data = cached_analytics('rep_range_distribution') { calculate_rep_range_distribution }

    # Session duration trends (last 20 workouts)
    @session_duration_data = Current.user.workouts
      .where.not(finished_at: nil)
      .where.not(started_at: nil)
      .order(finished_at: :desc)
      .limit(20)
      .map do |w|
        {
          date: w.finished_at.to_date.to_s,
          duration: w.duration_minutes || 0,
          gym: w.gym&.name || 'Unknown'
        }
      end.reverse

    # Exercise frequency (top 10 most performed exercises in last 90 days)
    @exercise_frequency_data = cached_analytics('exercise_frequency') { calculate_exercise_frequency }

    # Consistency streaks
    @streak_data = cached_analytics('streaks') { calculate_streaks }

    # Week-over-Week comparison
    @week_comparison_data = cached_analytics('week_comparison') { calculate_week_comparison }

    # Tonnage tracker (weekly volume over last 12 weeks)
    @tonnage_data = cached_analytics('tonnage') { calculate_tonnage_tracker }

    # Plateau detector (exercises with no PR in 4+ weeks)
    @plateau_data = cached_analytics('plateaus') { calculate_plateaus }

    # Training density (volume per minute over last 20 workouts)
    @training_density_data = cached_analytics('training_density') { calculate_training_density }

    # Muscle group volume distribution (last 7 days for recovery indicator)
    @muscle_group_data = cached_analytics('muscle_group_volume') { calculate_muscle_group_volume }

    # Muscle group spider chart data (last 30 days for balance)
    @muscle_balance_data = cached_analytics('muscle_balance') { calculate_muscle_balance }
  end

  # Calculate distribution of rep ranges (1-5, 6-10, 11-15, 16+) from last 30 days
  # Helps identify training bias toward strength vs hypertrophy vs endurance
  def calculate_rep_range_distribution
    # Analyze working sets only (exclude warmups)
    sets = Current.user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at >= ?', 30.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(reps: nil)
      .pluck(:reps)

    # Categorize into rep ranges
    {
      '1-5' => sets.count { |r| r >= 1 && r <= 5 },
      '6-10' => sets.count { |r| r >= 6 && r <= 10 },
      '11-15' => sets.count { |r| r >= 11 && r <= 15 },
      '16+' => sets.count { |r| r >= 16 }
    }
  end

  # Returns top 10 most frequently performed exercises in last 90 days
  # Useful for identifying training patterns and favorites
  def calculate_exercise_frequency
    exercise_counts = Current.user.workout_exercises
      .joins(workout_block: :workout)
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .group(:exercise_id)
      .count
      .sort_by { |(_, count)| -count }
      .first(10)

    exercise_names = Exercise.where(id: exercise_counts.map(&:first)).pluck(:id, :name).to_h

    exercise_counts.map do |exercise_id, count|
      {
        exercise: exercise_names[exercise_id] || 'Unknown',
        count: count
      }
    end
  end

  # Build chronological timeline of PRs (weight and volume) over last 12 months
  # Tracks the progressive improvement in each exercise
  # Only counts as PR if it beats a previous record (not just the first occurrence)
  def calculate_pr_timeline
    prs = []
    since = 12.months.ago

    historical_scope = Current.user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where('workouts.finished_at < ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)

    historical_best_weights = historical_scope
      .group('workout_exercises.exercise_id', 'workout_exercises.machine_id')
      .maximum(:weight_kg)

    historical_volume_by_workout_exercise = historical_scope
      .where('exercise_sets.reps > 0')
      .group('workout_exercises.id', 'workout_exercises.exercise_id', 'workout_exercises.machine_id')
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')

    historical_best_volumes = Hash.new(0)
    historical_volume_by_workout_exercise.each do |(workout_exercise_id, exercise_id, machine_id), volume|
      _ = workout_exercise_id
      combo_key = [ exercise_id, machine_id ]
      historical_best_volumes[combo_key] = [ historical_best_volumes[combo_key], volume ].max
    end

    recent_sets = Current.user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .where('exercise_sets.reps > 0')
      .where(exercises: { has_weight: true })
      .pluck(
        Arel.sql('workout_exercises.exercise_id'),
        Arel.sql('workout_exercises.machine_id'),
        Arel.sql('exercises.name'),
        :weight_kg,
        :reps,
        Arel.sql('COALESCE(exercise_sets.completed_at, exercise_sets.created_at)')
      )

    grouped_sets = recent_sets.group_by { |exercise_id, machine_id, *_| [ exercise_id, machine_id ] }

    grouped_sets.each do |(exercise_id, machine_id), sets_for_combo|
      exercise_name = sets_for_combo.first[2]
      next if exercise_name.blank?

      # Track running PRs starting from historical baseline
      best_weight = historical_best_weights[[ exercise_id, machine_id ]] || 0
      best_volume = historical_best_volumes[[ exercise_id, machine_id ]] || 0

      # Track if we've seen at least one set (first set is never a PR unless beating history)
      has_previous_set = best_weight > 0 || best_volume > 0

      sets_for_combo
        .sort_by { |(_, _, _, _, _, completed_at)| completed_at }
        .each do |(_, _, _, weight, reps, completed_at)|
        date = completed_at.to_date
        volume = (weight || 0) * (reps || 0)

        # Check for weight PR (must beat previous best AND have previous data)
        if weight > best_weight && has_previous_set
          prs << {
            exercise: exercise_name,
            date: date.to_s,
            weight: Current.user.display_weight(weight).round,
            reps: reps || 0,
            type: 'weight'
          }
        end
        best_weight = weight if weight > best_weight

        # Check for volume PR (must beat previous best AND have previous data)
        if volume > best_volume && has_previous_set
          prs << {
            exercise: exercise_name,
            date: date.to_s,
            weight: Current.user.display_weight(weight).round,
            reps: reps || 0,
            type: 'volume'
          }
        end
        best_volume = volume if volume > best_volume

        # After the first set, we have previous data
        has_previous_set = true
      end
    end

    # Sort by date and limit to most recent PRs for performance
    prs.sort_by { |pr| pr[:date] }.last(100)
  end

  # Calculate current and longest workout streaks (consecutive weeks with workouts)
  # Also shows days since last workout
  def calculate_streaks
    # Get all finished workout dates
    workout_dates = Current.user.workouts
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .pluck(:finished_at)
      .map { |dt| dt.to_date }
      .uniq

    return { current: 0, longest: 0, last_workout_days_ago: nil } if workout_dates.empty?

    # Calculate current streak (consecutive weeks with at least one workout)
    current_streak = 0
    today = Date.current
    current_week = today.beginning_of_week

    # Check if there's a workout this week or last week to start the streak
    weeks_to_check = (0..52).map { |i| (today - i.weeks).beginning_of_week }

    weeks_to_check.each do |week_start|
      week_end = week_start.end_of_week
      has_workout = workout_dates.any? { |d| d >= week_start && d <= week_end }

      if has_workout
        current_streak += 1
      else
        # Only break if we've started counting (allow gap for current week if it just started)
        break if current_streak > 0 || week_start < current_week
      end
    end

    # Calculate longest streak (consecutive weeks)
    longest_streak = 0
    temp_streak = 0
    all_weeks = workout_dates.map { |d| d.beginning_of_week }.uniq.sort.reverse

    all_weeks.each_with_index do |week, index|
      if index == 0
        temp_streak = 1
      else
        prev_week = all_weeks[index - 1]
        if (prev_week - week).to_i == 7
          temp_streak += 1
        else
          longest_streak = [ longest_streak, temp_streak ].max
          temp_streak = 1
        end
      end
    end
    longest_streak = [ longest_streak, temp_streak ].max

    # Days since last workout
    last_workout_days_ago = (today - workout_dates.first).to_i

    {
      current: current_streak,
      longest: longest_streak,
      last_workout_days_ago: last_workout_days_ago
    }
  end

  # Compare this week vs last week (volume, workout count, set count)
  # Shows if user is improving or regressing week over week
  def calculate_week_comparison
    this_week_start = Date.current.beginning_of_week
    last_week_start = (Date.current - 1.week).beginning_of_week
    range_start = last_week_start.beginning_of_day
    range_end = this_week_start.end_of_week
    this_week_key = week_bucket_key(this_week_start)
    last_week_key = week_bucket_key(last_week_start)

    volume_totals = Current.user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: range_start..range_end)
      .where(exercise_sets: { is_warmup: false })
      .group(Arel.sql("strftime('%Y-%W', workouts.finished_at)"))
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')

    workout_counts = Current.user.workouts
      .where(finished_at: range_start..range_end)
      .group(Arel.sql("strftime('%Y-%W', finished_at)"))
      .count

    set_counts = Current.user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { finished_at: range_start..range_end })
      .where(is_warmup: false)
      .group(Arel.sql("strftime('%Y-%W', workouts.finished_at)"))
      .count

    this_week_volume = volume_totals[this_week_key] || 0
    last_week_volume = volume_totals[last_week_key] || 0
    this_week_workouts = workout_counts[this_week_key] || 0
    last_week_workouts = workout_counts[last_week_key] || 0
    this_week_sets = set_counts[this_week_key] || 0
    last_week_sets = set_counts[last_week_key] || 0

    # Convert to user's unit
    this_week_volume = convert_volume_for_display(this_week_volume)
    last_week_volume = convert_volume_for_display(last_week_volume)

    {
      this_week: {
        volume: this_week_volume,
        workouts: this_week_workouts,
        sets: this_week_sets
      },
      last_week: {
        volume: last_week_volume,
        workouts: last_week_workouts,
        sets: last_week_sets
      }
    }
  end

  # Track total weekly volume (tonnage) over last 12 weeks
  # Shows training load trends over time
  def calculate_tonnage_tracker
    weekly_volumes = weekly_volume_totals(week_count: 12)

    build_weekly_series(week_count: 12) do |week_start|
      volume = weekly_volumes[week_bucket_key(week_start)] || 0
      {
        label: week_start.strftime('%b %d'),
        volume: convert_volume_for_display(volume)
      }
    end
  end

  # Identify exercises where user hasn't hit a PR in 4+ weeks (potential plateaus)
  # Only shows exercises that are still being trained (within last 30 days)
  def calculate_plateaus
    plateaus = []

    # Find currently active exercises with weight tracking
    active_exercises = Current.user.workout_exercises
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
    sets_by_exercise = Current.user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workout_exercises: { exercise_id: exercise_ids })
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(weight_kg: nil)
      .order(Arel.sql('workout_exercises.exercise_id ASC, workouts.finished_at ASC'))
      .pluck(Arel.sql('workout_exercises.exercise_id'), :weight_kg, :reps, Arel.sql('workouts.finished_at'))
      .group_by(&:first)

    active_exercises.each do |exercise_id, exercise_name|
      all_sets = sets_by_exercise[exercise_id]&.map { |(_, weight, reps, finished_at)| [ weight, reps, finished_at ] } || []

      next if all_sets.length < 3  # Need history to detect plateau

      # Track when last PR was hit
      best_weight = 0
      last_pr_date = nil

      all_sets.each do |weight, reps, finished_at|
        if weight > best_weight
          best_weight = weight
          last_pr_date = finished_at.to_date
        end
      end

      next unless last_pr_date

      # Calculate weeks since last PR
      weeks_since_pr = ((Date.current - last_pr_date) / 7).to_i

      # Only show if 4+ weeks without a PR and exercised recently (within 30 days)
      last_workout_date = all_sets.last[2].to_date
      days_since_last_workout = (Date.current - last_workout_date).to_i

      if weeks_since_pr >= 4 && days_since_last_workout <= 30
        plateaus << {
          exercise: exercise_name,
          weeks_since_pr: weeks_since_pr,
          best_weight: Current.user.display_weight(best_weight).round,
          last_pr_date: last_pr_date.strftime('%b %d')
        }
      end
    end

    # Sort by longest plateau first, limit to 5
    plateaus.sort_by { |p| -p[:weeks_since_pr] }.first(5)
  end

  # Calculate training density (volume per minute) for last 20 workouts
  # Higher density = more work in less time = improved work capacity
  def calculate_training_density
    # Analyze workout efficiency: volume divided by time
    workouts = Current.user.workouts
      .where.not(finished_at: nil)
      .where.not(started_at: nil)
      .includes(:gym)
      .order(finished_at: :desc)
      .limit(20)

    volumes_by_workout_id = Current.user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { id: workouts.map(&:id) })
      .where(is_warmup: false)
      .group(Arel.sql('workouts.id'))
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')

    workouts.map do |workout|
      duration_minutes = workout.duration_minutes || 0
      next nil if duration_minutes < 5  # Skip very short workouts

      volume = convert_volume_for_display(volumes_by_workout_id[workout.id] || 0)

      density = (volume / duration_minutes.to_f).round

      {
        date: workout.finished_at.to_date.to_s,
        density: density,
        volume: volume,
        duration: duration_minutes,
        gym: workout.gym&.name || 'Unknown'
      }
    end.compact.reverse
  end

  # Calculate volume per muscle group in last 7 days
  # Returns hash with muscle group as key and {volume, sets, last_trained} as value
  # Used for recovery indicator (how long since each muscle was trained)
  def calculate_muscle_group_volume
    muscle_stats = muscle_stats_for_window(since: 7.days.ago.beginning_of_day)

    # Convert volumes to user's preferred unit and calculate days since last trained
    muscle_stats.each_with_object({}) do |(muscle, stats), result|
      volume = stats[:volume]
      if Current.user.preferred_unit == 'lbs'
        volume = (volume * 2.20462).round
      else
        volume = volume.round
      end

      days_since = if stats[:last_trained]
        ((Time.current - stats[:last_trained]) / 1.day).round
      else
        999  # Never trained
      end

      result[muscle] = {
        volume: volume,
        sets: stats[:sets],
        days_since: days_since,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle] || '#71797E'
      }
    end
  end

  # Calculate consistency data: last 12 weeks + day-of-week pattern + current month
  def calculate_consistency_data
    # Last 12 weeks workout count
    weekly_counts = weekly_workout_counts(week_count: 12)
    twelve_weeks = build_weekly_series(week_count: 12) do |week_start|
      {
        week_start: week_start.strftime('%b %d'),
        count: weekly_counts[week_bucket_key(week_start)] || 0
      }
    end

    # Day of week pattern (last 90 days)
    day_pattern = Current.user.workouts
      .where('finished_at >= ?', 90.days.ago)
      .where.not(finished_at: nil)
      .group(Arel.sql("strftime('%w', finished_at)")) # 0=Sunday, 1=Monday, etc.
      .count

    # Convert to Monday-first ordering
    days_ordered = [ 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' ]
    day_counts = days_ordered.map.with_index do |day, idx|
      # Convert to database day number (0=Sunday, so Monday=1)
      db_day = (idx + 1) % 7
      { day: day, count: day_pattern[db_day.to_s] || 0 }
    end

    # Current month calendar data
    month_start = Time.current.beginning_of_month
    month_end = Time.current.end_of_month
    month_workouts = Current.user.workouts
      .where(finished_at: month_start..month_end)
      .where.not(finished_at: nil)
      .group(Arel.sql('DATE(finished_at)'))
      .count
      .transform_keys { |date| date.to_s }

    {
      twelve_weeks: twelve_weeks,
      day_pattern: day_counts,
      current_month: month_workouts,
      month_name: Time.current.strftime('%B %Y')
    }
  end

  # Calculate muscle group balance for spider/radar chart (last 30 days)
  # Returns normalized volume per muscle group (0-100 scale)
  def calculate_muscle_balance
    muscle_volumes = muscle_stats_for_window(since: 30.days.ago.beginning_of_day)
      .transform_values { |stats| stats[:volume] }

    # Find max volume for normalization
    max_volume = muscle_volumes.values.max || 1

    # Normalize to 0-100 scale and include all muscle groups
    Exercise::MUSCLE_GROUPS.map do |muscle|
      volume = muscle_volumes[muscle] || 0
      normalized = ((volume / max_volume.to_f) * 100).round

      {
        muscle: Exercise::MUSCLE_GROUP_LABELS[muscle],
        value: normalized,
        raw_volume: volume.round,
        color: Exercise::MUSCLE_GROUP_COLORS[muscle]
      }
    end
  end

  def build_weekly_series(week_count:)
    (0...week_count).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      yield week_start
    end.reverse
  end

  def week_bucket_key(week_start)
    week_start.strftime('%Y-%W')
  end

  def weekly_workout_counts(week_count:)
    range_start = (week_count - 1).weeks.ago.beginning_of_week
    range_end = Time.current.end_of_week

    Current.user.workouts
      .where(finished_at: range_start..range_end)
      .group(Arel.sql("strftime('%Y-%W', finished_at)"))
      .count
  end

  def weekly_volume_totals(week_count:)
    range_start = (week_count - 1).weeks.ago.beginning_of_week
    range_end = Time.current.end_of_week

    Current.user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: range_start..range_end)
      .where(exercise_sets: { is_warmup: false })
      .group(Arel.sql("strftime('%Y-%W', workouts.finished_at)"))
      .sum('COALESCE(exercise_sets.weight_kg, 0) * COALESCE(exercise_sets.reps, 0)')
  end

  def convert_volume_for_display(volume)
    if Current.user.preferred_unit == 'lbs'
      (volume * 2.20462).round
    else
      volume.round
    end
  end

  def cached_analytics(key, expires_in: 3.minutes, &block)
    DashboardAnalyticsCache.fetch(user_id: Current.user.id, key:, expires_in:, &block)
  end

  def muscle_stats_for_window(since:)
    stats_by_muscle = Hash.new { |hash, key| hash[key] = { volume: 0, sets: 0, last_trained: nil } }

    Current.user.exercise_sets
      .joins(workout_exercise: [ :exercise, { workout_block: :workout } ])
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })
      .where(is_warmup: false)
      .where.not(exercises: { primary_muscle_group: nil })
      .pluck(
        Arel.sql('exercises.primary_muscle_group'),
        :weight_kg,
        :reps,
        Arel.sql('workouts.finished_at')
      )
      .each do |muscle, weight_kg, reps, finished_at|
      entry = stats_by_muscle[muscle]
      entry[:volume] += (weight_kg || 0) * (reps || 0)
      entry[:sets] += 1

      if entry[:last_trained].nil? || finished_at > entry[:last_trained]
        entry[:last_trained] = finished_at
      end
    end

    stats_by_muscle
  end
end
