class DashboardController < ApplicationController
  def index
    return unless Current.user

    # Stats for dashboard
    @workouts_this_week = Current.user.workouts
      .where(finished_at: 1.week.ago.beginning_of_day..Time.current)
      .count

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

    # Heatmap data (last 365 days of workout activity)
    @heatmap_data = Current.user.workouts
      .where('finished_at >= ?', 365.days.ago.beginning_of_day)
      .where.not(finished_at: nil)
      .group('DATE(finished_at)')
      .count
      .transform_keys { |date| date.to_s }

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
  end

  private

  def calculate_rep_range_distribution
    # Get all working sets from the last 30 days
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

  def calculate_exercise_frequency
    # Count workout_exercises by exercise in last 90 days
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

  def calculate_pr_timeline
    prs = []

    # Get all workout exercises from the last 12 months with their sets
    workout_exercises = WorkoutExercise
      .joins(workout_block: :workout)
      .includes(:exercise, :exercise_sets)
      .where(workouts: { user_id: Current.user.id })
      .where('workouts.finished_at >= ?', 12.months.ago)
      .where.not(workouts: { finished_at: nil })

    # Group by exercise
    exercises_data = workout_exercises.group_by(&:exercise)

    exercises_data.each do |exercise, wes|
      next unless exercise&.has_weight?

      # Get all working sets in chronological order
      all_sets = wes.flat_map { |we|
        we.exercise_sets.select { |s| !s.is_warmup && s.weight_kg.present? }
      }.sort_by { |s| s.completed_at || s.created_at }

      next if all_sets.empty?

      # Track running PRs as we go through chronologically
      best_weight = 0
      best_volume = 0

      all_sets.each do |set|
        date = (set.completed_at || set.created_at).to_date
        weight = set.weight_kg
        volume = (set.weight_kg || 0) * (set.reps || 0)

        # Check for weight PR
        if weight > best_weight
          best_weight = weight
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: Current.user.display_weight(weight).round,
            reps: set.reps || 0,
            type: 'weight'
          }
        end

        # Check for volume PR (same date might have both)
        if volume > best_volume
          best_volume = volume
          prs << {
            exercise: exercise.name,
            date: date.to_s,
            weight: Current.user.display_weight(set.weight_kg).round,
            reps: set.reps || 0,
            type: 'volume'
          }
        end
      end
    end

    # Sort by date and limit to most recent PRs for performance
    prs.sort_by { |pr| pr[:date] }.last(100)
  end

  def calculate_streaks
    # Get all workout dates (finished workouts only) in descending order
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

  def calculate_tonnage_tracker
    # Weekly volume for the last 12 weeks
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

  def calculate_plateaus
    plateaus = []

    # Get exercises performed in the last 90 days with weighted sets
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

  def calculate_training_density
    # Get last 20 workouts with duration and volume
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
end
