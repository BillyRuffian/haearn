# frozen_string_literal: true

# Calculates weekly workout summary statistics for email reports
# Compares this week's performance to historical averages
#
# Usage:
#   calculator = WeeklySummaryCalculator.new(user: user, week_start: 1.week.ago)
#   summary = calculator.calculate
class WeeklySummaryCalculator
  attr_reader :user, :week_start, :week_end

  def initialize(user:, week_start: nil)
    @user = user
    @week_start = week_start || Time.current.beginning_of_week
    @week_end = @week_start.end_of_week
  end

  # Calculates complete weekly summary with comparisons to averages
  # Returns hash with this_week stats and vs_average comparisons
  def calculate
    {
      week_label: week_label,
      this_week: this_week_stats,
      vs_average: vs_average_stats,
      highlights: highlights,
      top_exercises: top_exercises,
      new_prs: new_prs,
      consistency: consistency_stats
    }
  end

  private

  def week_label
    if week_start.to_date == Time.current.beginning_of_week.to_date
      'This Week'
    else
      week_start.strftime('%b %-d') + ' - ' + week_end.strftime('%b %-d, %Y')
    end
  end

  # Stats for the target week
  def this_week_stats
    workouts = user.workouts.where(finished_at: week_start..week_end)

    working_sets = ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { id: workouts.pluck(:id), user_id: user.id })
      .where(is_warmup: false)

    total_volume = working_sets.sum('weight_kg * reps')

    {
      workout_count: workouts.count,
      total_volume_kg: total_volume.round,
      total_sets: working_sets.count,
      total_reps: working_sets.sum(:reps) || 0,
      total_duration_minutes: workouts.sum('CAST((julianday(finished_at) - julianday(started_at)) * 24 * 60 AS INTEGER)') || 0,
      unique_exercises: workouts.joins(workout_blocks: :workout_exercises).distinct.count('workout_exercises.exercise_id')
    }
  end

  # Historical average stats (last 12 weeks before target week, excluding target week)
  def vs_average_stats
    historical_start = week_start - 12.weeks
    historical_end = week_start - 1.day

    historical_workouts = user.workouts.where(finished_at: historical_start..historical_end)
    num_weeks = 12.0

    return nil if historical_workouts.empty?

    avg_workout_count = (historical_workouts.count / num_weeks).round(1)

    working_sets = ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { id: historical_workouts.pluck(:id), user_id: user.id })
      .where(is_warmup: false)

    avg_volume = (working_sets.sum('weight_kg * reps') / num_weeks).round
    avg_sets = (working_sets.count / num_weeks).round
    avg_duration = (historical_workouts.sum('CAST((julianday(finished_at) - julianday(started_at)) * 24 * 60 AS INTEGER)') / num_weeks).round

    this_week = this_week_stats

    {
      avg_workout_count: avg_workout_count,
      avg_volume_kg: avg_volume,
      avg_sets: avg_sets,
      avg_duration_minutes: avg_duration,
      workout_count_diff: this_week[:workout_count] - avg_workout_count,
      volume_diff_kg: this_week[:total_volume_kg] - avg_volume,
      sets_diff: this_week[:total_sets] - avg_sets,
      workout_count_pct: calculate_percent_change(this_week[:workout_count], avg_workout_count),
      volume_pct: calculate_percent_change(this_week[:total_volume_kg], avg_volume),
      sets_pct: calculate_percent_change(this_week[:total_sets], avg_sets)
    }
  end

  # Notable highlights/achievements for the week
  def highlights
    highlights = []

    this_week = this_week_stats
    vs_avg = vs_average_stats

    # Volume milestones
    if vs_avg && this_week[:total_volume_kg] > vs_avg[:avg_volume_kg] * 1.2
      highlights << { type: :volume_spike, message: "Crushed #{vs_avg[:volume_pct].abs}% more volume than average!" }
    end

    # Consistency
    if this_week[:workout_count] >= 4
      highlights << { type: :consistency, message: "#{this_week[:workout_count]} workouts - excellent consistency!" }
    elsif this_week[:workout_count] == 0
      highlights << { type: :missed_week, message: "No workouts this week - let's get back on track!" }
    end

    # PR count
    pr_count = new_prs.count
    if pr_count > 0
      highlights << { type: :prs, message: "#{pr_count} new personal #{pr_count == 1 ? 'record' : 'records'}!" }
    end

    highlights
  end

  # Top exercises by volume for the week
  def top_exercises
    workouts = user.workouts.where(finished_at: week_start..week_end)

    ExerciseSet
      .joins(workout_exercise: { workout_block: :workout })
      .joins('INNER JOIN exercises ON exercises.id = workout_exercises.exercise_id')
      .where(workouts: { id: workouts.pluck(:id) })
      .where(is_warmup: false)
      .group(Arel.sql('exercises.id, exercises.name'))
      .select(Arel.sql('exercises.name, SUM(weight_kg * reps) as total_volume_kg, COUNT(*) as set_count'))
      .order(Arel.sql('total_volume_kg DESC'))
      .limit(5)
      .map do |result|
        {
          exercise_name: result.name,
          volume_kg: result.total_volume_kg.round,
          set_count: result.set_count
        }
      end
  end

  # New PRs achieved this week
  def new_prs
    workouts = user.workouts.where(finished_at: week_start..week_end)
    prs = []

    workouts.each do |workout|
      workout.workout_blocks.each do |block|
        block.workout_exercises.each do |we|
          we_prs = PrCalculator.calculate_all([ we ], exercise: we.exercise)

          # Check if this session has a PR that's actually from this week
          if we_prs[:best_set_weight] && we_prs[:best_set_weight][:date] >= week_start.to_date
            prs << {
              exercise_name: we.exercise.name,
              pr_type: :weight,
              value_kg: we_prs[:best_set_weight][:weight_kg],
              reps: we_prs[:best_set_weight][:reps],
              date: we_prs[:best_set_weight][:date]
            }
          end
        end
      end
    end

    prs.uniq { |pr| [ pr[:exercise_name], pr[:pr_type] ] }.take(5)
  end

  # Consistency metrics
  def consistency_stats
    this_week = this_week_stats
    last_4_weeks = user.workouts.where(finished_at: (week_start - 4.weeks)..week_end)

    weeks_with_workouts = last_4_weeks
      .group(Arel.sql("strftime('%Y-%W', finished_at)"))
      .count
      .count

    {
      weeks_trained_last_4: weeks_with_workouts,
      current_streak: calculate_streak
    }
  end

  # Calculate current workout streak (weeks with at least 1 workout)
  def calculate_streak
    streak = 0
    check_date = week_start

    loop do
      week_start_check = check_date.beginning_of_week
      week_end_check = check_date.end_of_week

      has_workout = user.workouts.where(finished_at: week_start_check..week_end_check).exists?

      break unless has_workout

      streak += 1
      check_date -= 1.week

      # Limit lookback to 52 weeks
      break if streak >= 52
    end

    streak
  end

  def calculate_percent_change(current, average)
    return 0 if average.zero?

    ((current - average) / average * 100).round
  end
end
