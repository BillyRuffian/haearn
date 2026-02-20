require 'test_helper'

class FatigueAnalyzerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @gym = gyms(:one)
    @exercise = Exercise.create!(
      name: 'Fatigue Scope Test Lift',
      has_weight: true,
      exercise_type: 'reps',
      primary_muscle_group: 'chest',
      user: @user
    )
    @machine_a = Machine.create!(
      gym: @gym,
      name: 'Fatigue Scope Machine A',
      equipment_type: 'machine'
    )
    @machine_b = Machine.create!(
      gym: @gym,
      name: 'Fatigue Scope Machine B',
      equipment_type: 'machine'
    )
  end

  test 'baseline sessions are scoped to the same machine' do
    create_historical_session(machine: @machine_a, finished_at: 6.days.ago, sets: [ [ 100, 5 ] ])
    create_historical_session(machine: @machine_b, finished_at: 4.days.ago, sets: [ [ 220, 5 ] ])
    current_we = create_historical_session(machine: @machine_a, finished_at: 1.day.ago, sets: [ [ 95, 5 ] ])

    result = FatigueAnalyzer.new(workout_exercise: current_we, user: @user).analyze

    assert result
    assert_equal 1, result[:sessions_analyzed]
  end

  private

  def create_historical_session(machine:, finished_at:, sets:)
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: finished_at - 45.minutes,
      finished_at: finished_at
    )

    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(
      exercise: @exercise,
      machine: machine,
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

    workout_exercise
  end
end
