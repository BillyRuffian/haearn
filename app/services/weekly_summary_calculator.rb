# frozen_string_literal: true

# Calculates weekly workout summary statistics for email reports
# Compares this week's performance to historical averages
#
# Usage:
#   calculator = WeeklySummaryCalculator.new(user: user, week_start: 1.week.ago)
#   summary = calculator.calculate
class WeeklySummaryCalculator
  DURATION_MINUTES_SQL = <<~SQL.squish.freeze
    (julianday(finished_at) - julianday(started_at)) * 24 * 60
  SQL

  attr_reader :user, :week_start, :week_end

  def initialize(user:, week_start: nil)
    @user = user
    @week_start = (week_start || Time.current).beginning_of_week
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
    @this_week_stats ||= display_stats(this_week_raw_stats)
  end

  # Historical averages use up to 12 prior calendar weeks. For newer users, the
  # denominator starts with their first completed workout week in that window.
  def vs_average_stats
    return @vs_average_stats if defined?(@vs_average_stats)

    historical_workouts = workouts_between(week_start - 12.weeks, week_start)
    first_workout_at = historical_workouts.minimum(:finished_at)
    return @vs_average_stats = nil unless first_workout_at

    baseline_weeks = baseline_week_count(first_workout_at)
    historical = raw_stats_for(historical_workouts)
    averages = historical.transform_values { |value| value.to_f / baseline_weeks }
    current = this_week_raw_stats

    @vs_average_stats = {
      baseline_weeks: baseline_weeks,
      avg_workout_count: averages[:workout_count].round(1),
      avg_volume_kg: averages[:total_volume_kg].round(1),
      avg_sets: averages[:total_sets].round(1),
      avg_duration_minutes: averages[:total_duration_minutes].round(1),
      workout_count_diff: (current[:workout_count] - averages[:workout_count]).round(1),
      volume_diff_kg: (current[:total_volume_kg] - averages[:total_volume_kg]).round(1),
      sets_diff: (current[:total_sets] - averages[:total_sets]).round(1),
      duration_diff_minutes: (current[:total_duration_minutes] - averages[:total_duration_minutes]).round(1),
      workout_count_pct: calculate_percent_change(current[:workout_count], averages[:workout_count]),
      volume_pct: calculate_percent_change(current[:total_volume_kg], averages[:total_volume_kg]),
      sets_pct: calculate_percent_change(current[:total_sets], averages[:total_sets]),
      duration_pct: calculate_percent_change(current[:total_duration_minutes], averages[:total_duration_minutes])
    }
  end

  # Notable highlights/achievements for the week
  def highlights
    highlights = []

    this_week = this_week_stats
    vs_avg = vs_average_stats

    # Volume milestones
    if (vs_avg&.dig(:volume_pct) || 0) > 20
      highlights << { type: :volume_spike, message: "Moved #{vs_avg[:volume_pct]}% more volume than average." }
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
    workouts = workouts_between(week_start, week_start + 1.week)

    user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .joins('INNER JOIN exercises ON exercises.id = workout_exercises.exercise_id')
      .where(workouts: { id: workouts.select(:id) })
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
    workouts = workouts_between(week_start, week_start + 1.week)
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
    last_4_weeks = workouts_between(week_start - 3.weeks, week_start + 1.week)

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
    return nil if average.zero?

    ((current - average) / average * 100).round
  end

  def this_week_raw_stats
    @this_week_raw_stats ||= raw_stats_for(workouts_between(week_start, week_start + 1.week))
  end

  def raw_stats_for(workouts)
    recorded_sets = user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .where(workouts: { id: workouts.select(:id) })
    working_sets = recorded_sets.where(is_warmup: false)

    {
      workout_count: workouts.count,
      total_volume_kg: working_sets.sum('weight_kg * reps').to_f,
      total_sets: working_sets.count,
      total_reps: working_sets.sum(:reps).to_i,
      total_duration_minutes: workouts.sum(DURATION_MINUTES_SQL).to_f,
      unique_exercises: recorded_sets.distinct.count('workout_exercises.exercise_id')
    }
  end

  def display_stats(stats)
    stats.merge(
      total_volume_kg: stats[:total_volume_kg].round,
      total_duration_minutes: stats[:total_duration_minutes].round
    )
  end

  def workouts_between(range_start, range_end)
    user.workouts.where(finished_at: range_start...range_end)
  end

  def baseline_week_count(first_workout_at)
    first_week = first_workout_at.in_time_zone.beginning_of_week.to_date
    ((week_start.to_date - first_week) / 7).to_i.clamp(1, 12)
  end
end
