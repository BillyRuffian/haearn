# Displays the main dashboard with workout statistics, charts, and analytics
# Shows workout frequency, volume tracking, PR timeline, heatmaps, and more
class DashboardController < ApplicationController
  # GET /dashboard
  # Main dashboard view with comprehensive workout analytics
  def index
    return unless Current.user

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
    @pr_timeline_data = calculate_pr_timeline

    # PRs this month (count from timeline data)
    start_of_month = Time.current.beginning_of_month.to_date.to_s
    @prs_this_month = @pr_timeline_data.count { |pr| pr[:date] >= start_of_month }

    # Recent workouts (last 5 completed)
    @recent_workouts = Current.user.workouts
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .limit(5)

    # Workout frequency data for chart (last 8 weeks)
    @workout_frequency = (0..7).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      week_end = weeks_ago.weeks.ago.end_of_week
      {
        label: week_start.strftime('%b %d'),
        count: Current.user.workouts.where(finished_at: week_start..week_end).count
      }
    end.reverse

    # Consistency data for compact visualization
    @consistency_data = calculate_consistency_data

    # Rep range distribution (last 30 days)
    @rep_range_data = calculate_rep_range_distribution

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
    @exercise_frequency_data = calculate_exercise_frequency

    # Consistency streaks
    @streak_data = calculate_streaks

    # Week-over-Week comparison
    @week_comparison_data = calculate_week_comparison

    # Tonnage tracker (weekly volume over last 12 weeks)
    @tonnage_data = calculate_tonnage_tracker

    # Plateau detector (exercises with no PR in 4+ weeks)
    @plateau_data = calculate_plateaus

    # Training density (volume per minute over last 20 workouts)
    @training_density_data = calculate_training_density

    # Muscle group volume distribution (last 7 days for recovery indicator)
    @muscle_group_data = calculate_muscle_group_volume

    # Muscle group spider chart data (last 30 days for balance)
    @muscle_balance_data = calculate_muscle_balance
  end

  private

  # Calculate distribution of rep ranges (1-5, 6-10, 11-15, 16+) from last 30 days
  # Helps identify training bias toward strength vs hypertrophy vs endurance
  def calculate_rep_range_distribution
    # Analyze working sets only (exclude warmups)
    sets = ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { user_id: Current.user.id })
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
    # Count how many times each exercise appeared in workouts
    WorkoutExercise
      .joins(:exercise, workout_block: :workout)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .group('exercises.name')
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .map { |name, count| { exercise: name, count: count } }
  end

  # Build chronological timeline of PRs (weight and volume) over last 12 months
  # Tracks the progressive improvement in each exercise
  # Only counts as PR if it beats a previous record (not just the first occurrence)
  def calculate_pr_timeline
    prs = []
    since = 12.months.ago

    # Load 12 months of workout data with sets
    workout_exercises = WorkoutExercise
      .joins(workout_block: :workout)
      .includes(:exercise, :machine, :exercise_sets)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', since)
      .where.not(workouts: { finished_at: nil })

    # Group by exercise+machine for proper scoping
    exercises_data = workout_exercises.group_by { |we| [ we.exercise_id, we.machine_id ] }

    exercises_data.each do |(exercise_id, machine_id), wes|
      exercise = wes.first.exercise
      next unless exercise&.has_weight?

      # Get historical best BEFORE the time period to establish baseline
      historical_best_weight = ExerciseSet
        .joins(workout_exercise: { workout_block: :workout })
        .where(workout_exercises: { exercise_id: exercise_id, machine_id: machine_id })
        .where(workouts: { user_id: Current.user.id })
        .where('workouts.finished_at < ?', since)
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil)
        .maximum(:weight_kg) || 0

      historical_best_volume = 0
      WorkoutExercise
        .joins(workout_block: :workout)
        .includes(:exercise_sets)
        .where(exercise_id: exercise_id, machine_id: machine_id)
        .where(workouts: { user_id: Current.user.id })
        .where('workouts.finished_at < ?', since)
        .where.not(workouts: { finished_at: nil })
        .each do |we|
          vol = we.exercise_sets
            .select { |s| !s.is_warmup && s.weight_kg.present? && s.reps&.positive? }
            .sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
          historical_best_volume = vol if vol > historical_best_volume
        end

      # Get all working sets in chronological order within the time period
      all_sets = wes.flat_map { |we|
        we.exercise_sets.select { |s| !s.is_warmup && s.weight_kg.present? && s.reps&.positive? }
      }.sort_by { |s| s.completed_at || s.created_at }

      next if all_sets.empty?

      # Track running PRs starting from historical baseline
      best_weight = historical_best_weight
      best_volume = historical_best_volume

      # Track if we've seen at least one set (first set is never a PR unless beating history)
      has_previous_set = historical_best_weight > 0 || historical_best_volume > 0

      all_sets.each do |set|
        date = (set.completed_at || set.created_at).to_date
        weight = set.weight_kg
        volume = (set.weight_kg || 0) * (set.reps || 0)

        # Check for weight PR (must beat previous best AND have previous data)
        if weight > best_weight && has_previous_set
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: Current.user.display_weight(weight).round,
            reps: set.reps || 0,
            type: 'weight'
          }
        end
        best_weight = weight if weight > best_weight

        # Check for volume PR (must beat previous best AND have previous data)
        if volume > best_volume && has_previous_set
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: Current.user.display_weight(set.weight_kg).round,
            reps: set.reps || 0,
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

    # This week's volume
    this_week_volume = Current.user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: this_week_start..this_week_start.end_of_week)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    # Last week's volume
    last_week_volume = Current.user.workouts
      .joins(workout_exercises: :exercise_sets)
      .where(finished_at: last_week_start..last_week_start.end_of_week)
      .where(exercise_sets: { is_warmup: false })
      .sum('exercise_sets.weight_kg * exercise_sets.reps')

    # This week's workouts count
    this_week_workouts = Current.user.workouts
      .where(finished_at: this_week_start..this_week_start.end_of_week)
      .count

    # Last week's workouts count
    last_week_workouts = Current.user.workouts
      .where(finished_at: last_week_start..last_week_start.end_of_week)
      .count

    # This week's total sets
    this_week_sets = ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { user_id: Current.user.id })
      .where(workouts: { finished_at: this_week_start..this_week_start.end_of_week })
      .where(is_warmup: false)
      .count

    # Last week's total sets
    last_week_sets = ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { user_id: Current.user.id })
      .where(workouts: { finished_at: last_week_start..last_week_start.end_of_week })
      .where(is_warmup: false)
      .count

    # Convert to user's unit
    if Current.user.preferred_unit == 'lbs'
      this_week_volume = (this_week_volume * 2.20462).round
      last_week_volume = (last_week_volume * 2.20462).round
    else
      this_week_volume = this_week_volume.round
      last_week_volume = last_week_volume.round
    end

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
    # Sum volume for each week
    (0..11).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      week_end = weeks_ago.weeks.ago.end_of_week

      volume = Current.user.workouts
        .joins(workout_exercises: :exercise_sets)
        .where(finished_at: week_start..week_end)
        .where(exercise_sets: { is_warmup: false })
        .sum('exercise_sets.weight_kg * exercise_sets.reps')

      # Convert to user's unit
      if Current.user.preferred_unit == 'lbs'
        volume = (volume * 2.20462).round
      else
        volume = volume.round
      end

      {
        label: week_start.strftime('%b %d'),
        volume: volume
      }
    end.reverse
  end

  # Identify exercises where user hasn't hit a PR in 4+ weeks (potential plateaus)
  # Only shows exercises that are still being trained (within last 30 days)
  def calculate_plateaus
    plateaus = []

    # Find currently active exercises with weight tracking
    active_exercises = WorkoutExercise
      .joins(:exercise, :exercise_sets, workout_block: :workout)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', 90.days.ago)
      .where.not(workouts: { finished_at: nil })
      .where(exercises: { has_weight: true })
      .where(exercise_sets: { is_warmup: false })
      .where.not(exercise_sets: { weight_kg: nil })
      .select('exercises.id, exercises.name')
      .distinct
      .pluck('exercises.id', 'exercises.name')

    active_exercises.each do |exercise_id, exercise_name|
      # Get all working sets for this exercise, chronologically
      all_sets = ExerciseSet
        .joins(workout_exercise: { workout_block: :workout })
        .where(workouts: { user_id: Current.user.id })
        .where(workout_exercises: { exercise_id: exercise_id })
        .where.not(workouts: { finished_at: nil })
        .where(is_warmup: false)
        .where.not(weight_kg: nil)
        .order('workouts.finished_at ASC')
        .pluck(:weight_kg, :reps, 'workouts.finished_at')

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
      .order(finished_at: :desc)
      .limit(20)

    workouts.map do |workout|
      duration_minutes = workout.duration_minutes || 0
      next nil if duration_minutes < 5  # Skip very short workouts

      volume = workout.exercise_sets
        .where(is_warmup: false)
        .sum('COALESCE(weight_kg, 0) * COALESCE(reps, 0)')

      # Convert to user's unit
      if Current.user.preferred_unit == 'lbs'
        volume = (volume * 2.20462).round
      else
        volume = volume.round
      end

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
    seven_days_ago = 7.days.ago.beginning_of_day

    # Get all workout exercises from last 7 days with their exercise's muscle group
    workout_exercises = WorkoutExercise
      .joins(:exercise, workout_block: :workout)
      .includes(:exercise_sets)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', seven_days_ago)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })

    # Group by muscle and calculate stats
    muscle_stats = {}

    workout_exercises.each do |we|
      muscle = we.exercise.primary_muscle_group
      next unless muscle

      muscle_stats[muscle] ||= { volume: 0, sets: 0, last_trained: nil }

      # Calculate volume for this exercise
      volume = we.exercise_sets.where(is_warmup: false).sum do |set|
        (set.weight_kg || 0) * (set.reps || 0)
      end

      muscle_stats[muscle][:volume] += volume
      muscle_stats[muscle][:sets] += we.exercise_sets.where(is_warmup: false).count

      workout_date = we.workout_block.workout.finished_at
      if muscle_stats[muscle][:last_trained].nil? || workout_date > muscle_stats[muscle][:last_trained]
        muscle_stats[muscle][:last_trained] = workout_date
      end
    end

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
    twelve_weeks = (0..11).map do |weeks_ago|
      week_start = weeks_ago.weeks.ago.beginning_of_week
      week_end = weeks_ago.weeks.ago.end_of_week
      count = Current.user.workouts.where(finished_at: week_start..week_end).count
      {
        week_start: week_start.strftime('%b %d'),
        count: count
      }
    end.reverse

    # Day of week pattern (last 90 days)
    day_pattern = Current.user.workouts
      .where('finished_at >= ?', 90.days.ago)
      .where.not(finished_at: nil)
      .group("strftime('%w', finished_at)") # 0=Sunday, 1=Monday, etc.
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
      .group('DATE(finished_at)')
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
    thirty_days_ago = 30.days.ago.beginning_of_day

    # Get all workout exercises from last 30 days
    workout_exercises = WorkoutExercise
      .joins(:exercise, workout_block: :workout)
      .includes(:exercise_sets)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', thirty_days_ago)
      .where.not(workouts: { finished_at: nil })
      .where.not(exercises: { primary_muscle_group: nil })

    # Calculate volume per muscle group
    muscle_volumes = {}

    workout_exercises.each do |we|
      muscle = we.exercise.primary_muscle_group
      next unless muscle

      muscle_volumes[muscle] ||= 0

      volume = we.exercise_sets.where(is_warmup: false).sum do |set|
        (set.weight_kg || 0) * (set.reps || 0)
      end

      muscle_volumes[muscle] += volume
    end

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
end
