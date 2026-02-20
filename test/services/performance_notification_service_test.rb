require 'test_helper'

class PerformanceNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @gym = gyms(:one)
    @exercise = Exercise.create!(
      name: 'Notification Test Lift',
      has_weight: true,
      exercise_type: 'reps',
      primary_muscle_group: 'chest',
      user: @user
    )
    @machine = Machine.create!(
      gym: @gym,
      name: 'Notification Test Machine',
      equipment_type: 'machine'
    )
  end

  test 'does not create weekly volume drop notification before any workout this week' do
    travel_to Time.zone.local(2026, 2, 16, 9, 0, 0) do
      create_workout_with_volume_at(
        started_at: Time.zone.local(2026, 2, 10, 8, 0, 0),
        finished_at: Time.zone.local(2026, 2, 10, 8, 45, 0),
        sets: [ [ 100, 10 ], [ 90, 10 ] ]
      )

      notifications = PerformanceNotificationService.new(user: @user).refresh!
      volume_drop = notifications.find { |n| n.kind == 'volume_drop' }

      assert_nil volume_drop
    end
  end

  test 'creates streak risk notification when user has not trained for several days' do
    create_workout_with_volume(days_ago: 5, sets: [ [ 100, 5 ] ])

    notifications = PerformanceNotificationService.new(user: @user).refresh!
    streak_notification = notifications.find { |n| n.kind == 'streak_risk' }

    assert streak_notification
    assert_match(/No workout logged in/, streak_notification.message)
  end

  test 'creates weekly volume drop notification' do
    # Last week: high volume
    create_workout_with_volume(days_ago: 8, sets: [ [ 100, 10 ], [ 100, 10 ] ])
    # This week: low volume
    create_workout_with_volume(days_ago: 1, sets: [ [ 50, 4 ] ])

    notifications = PerformanceNotificationService.new(user: @user).refresh!
    volume_drop = notifications.find { |n| n.kind == 'volume_drop' }

    assert volume_drop
    assert_equal 'warning', volume_drop.severity
  end

  test 'refresh is idempotent by dedupe key' do
    create_workout_with_volume(days_ago: 5, sets: [ [ 100, 5 ] ])
    service = PerformanceNotificationService.new(user: @user)

    service.refresh!
    first_count = @user.notifications.count
    service.refresh!
    second_count = @user.notifications.count

    assert_equal first_count, second_count
  end

  test 'does not create streak risk notification when preference is disabled' do
    @user.update!(notify_streak_risk: false)
    create_workout_with_volume(days_ago: 5, sets: [ [ 100, 5 ] ])

    notifications = PerformanceNotificationService.new(user: @user).refresh!

    assert_nil notifications.find { |n| n.kind == 'streak_risk' }
  end

  private

  def create_workout_with_volume(days_ago:, sets:)
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: days_ago.days.ago,
      finished_at: days_ago.days.ago + 45.minutes
    )

    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )

    sets.each_with_index do |(weight, reps), index|
      workout_exercise.exercise_sets.create!(
        weight_kg: weight,
        reps: reps,
        is_warmup: false,
        position: index + 1,
        completed_at: days_ago.days.ago
      )
    end
  end

  def create_workout_with_volume_at(started_at:, finished_at:, sets:)
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: started_at,
      finished_at: finished_at
    )

    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )

    sets.each_with_index do |(weight, reps), index|
      workout_exercise.exercise_sets.create!(
        weight_kg: weight,
        reps: reps,
        is_warmup: false,
        position: index + 1,
        completed_at: finished_at
      )
    end
  end
end
