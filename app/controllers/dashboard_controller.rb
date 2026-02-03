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
      .sum("exercise_sets.weight_kg * exercise_sets.reps")

    # Convert volume to user's preferred unit
    if Current.user.preferred_unit == "lbs"
      @volume_this_week = (@volume_this_week * 2.20462).round
    else
      @volume_this_week = @volume_this_week.round
    end

    # PRs tracking not yet implemented
    @prs_this_month = 0

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
        label: week_start.strftime("%b %d"),
        count: Current.user.workouts.where(finished_at: week_start..week_end).count
      }
    end.reverse
  end
end
