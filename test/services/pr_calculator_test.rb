require 'test_helper'

class PrCalculatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @gym = gyms(:one)
    # Create fresh exercise with no fixture data to avoid interference
    @exercise = Exercise.create!(
      name: 'Test Bench Press',
      has_weight: true,
      exercise_type: 'reps',
      user: @user
    )
    @machine = Machine.create!(
      name: 'Test Machine',
      gym: @gym,
      equipment_type: 'machine'
    )
  end

  # Helper to create a completed workout with sets
  def create_workout_with_sets(weights_and_reps, days_ago: 0)
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: days_ago.days.ago,
      finished_at: days_ago.days.ago + 1.hour
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )

    weights_and_reps.each_with_index do |entry, idx|
      weight, reps, attrs = if entry.is_a?(Hash)
                              [ entry[:weight], entry[:reps], entry ]
      else
                              [ entry[0], entry[1], {} ]
      end

      we.exercise_sets.create!(
        weight_kg: weight,
        reps: reps,
        position: idx + 1,
        is_warmup: false,
        completed_at: days_ago.days.ago,
        belt: attrs.fetch(:belt, false),
        knee_sleeves: attrs.fetch(:knee_sleeves, false),
        wrist_wraps: attrs.fetch(:wrist_wraps, false),
        straps: attrs.fetch(:straps, false)
      )
    end

    [ workout, we ]
  end

  test 'calculate_all returns empty PRs for empty collection' do
    prs = PrCalculator.calculate_all([], exercise: @exercise)

    assert_nil prs[:best_set_weight]
    assert_nil prs[:best_set_volume]
    assert_nil prs[:best_session_volume]
    assert_nil prs[:best_e1rm]
  end

  test 'calculate_all finds best set weight' do
    _, we1 = create_workout_with_sets([ [ 80, 5 ], [ 85, 3 ] ], days_ago: 7)
    _, we2 = create_workout_with_sets([ [ 90, 2 ], [ 75, 8 ] ], days_ago: 1)

    prs = PrCalculator.calculate_all([ we1, we2 ], exercise: @exercise)

    assert_equal 90, prs[:best_set_weight][:weight_kg]
    assert_equal 2, prs[:best_set_weight][:reps]
  end

  test 'calculate_all finds best set volume' do
    _, we1 = create_workout_with_sets([ [ 80, 5 ], [ 85, 3 ] ], days_ago: 7)  # 400, 255
    _, we2 = create_workout_with_sets([ [ 70, 10 ], [ 75, 8 ] ], days_ago: 1) # 700, 600

    prs = PrCalculator.calculate_all([ we1, we2 ], exercise: @exercise)

    assert_equal 700, prs[:best_set_volume][:volume]
    assert_equal 70, prs[:best_set_volume][:weight_kg]
    assert_equal 10, prs[:best_set_volume][:reps]
  end

  test 'calculate_all finds best session volume' do
    _, we1 = create_workout_with_sets([ [ 80, 5 ], [ 80, 5 ], [ 80, 5 ] ], days_ago: 7)  # 1200
    _, we2 = create_workout_with_sets([ [ 70, 10 ], [ 70, 10 ] ], days_ago: 1)          # 1400

    prs = PrCalculator.calculate_all([ we1, we2 ], exercise: @exercise)

    assert_equal 1400, prs[:best_session_volume][:volume]
  end

  test 'calculate_all finds best estimated 1RM' do
    _, we1 = create_workout_with_sets([ [ 100, 1 ] ], days_ago: 7)   # e1RM = 100
    _, we2 = create_workout_with_sets([ [ 85, 8 ] ], days_ago: 1)    # e1RM ~106 (higher due to more reps)

    prs = PrCalculator.calculate_all([ we1, we2 ], exercise: @exercise)

    # Best e1RM should be from 85x8 (higher than 100x1)
    assert prs[:best_e1rm]
    assert prs[:best_e1rm][:e1rm_kg] > 100
    assert_equal 85, prs[:best_e1rm][:weight_kg]
    assert_equal 8, prs[:best_e1rm][:reps]
  end

  test 'volume_pr? returns false for first workout' do
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil  # Still in progress
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    we.exercise_sets.create!(weight_kg: 100, reps: 5, position: 1, is_warmup: false)

    assert_not PrCalculator.volume_pr?(we)
  end

  test 'volume_pr? returns true when volume exceeds previous' do
    # Previous workout
    create_workout_with_sets([ [ 80, 5 ], [ 80, 5 ] ], days_ago: 7)  # 800

    # Current workout (in progress)
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    we.exercise_sets.create!(weight_kg: 85, reps: 5, position: 1, is_warmup: false)
    we.exercise_sets.create!(weight_kg: 85, reps: 5, position: 2, is_warmup: false)  # 850 > 800

    assert PrCalculator.volume_pr?(we)
  end

  test 'weight_pr? returns false for first workout' do
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    set = we.exercise_sets.create!(weight_kg: 100, reps: 5, position: 1, is_warmup: false)

    assert_not PrCalculator.weight_pr?(set)
  end

  test 'weight_pr? returns true when weight exceeds previous best' do
    # Previous workout
    create_workout_with_sets([ [ 80, 5 ], [ 85, 3 ] ], days_ago: 7)

    # Current workout
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    set = we.exercise_sets.create!(weight_kg: 90, reps: 2, position: 1, is_warmup: false)

    assert PrCalculator.weight_pr?(set)
  end

  test 'weight_pr? returns false for warmup sets' do
    create_workout_with_sets([ [ 80, 5 ] ], days_ago: 7)

    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    warmup_set = we.exercise_sets.create!(weight_kg: 100, reps: 5, position: 1, is_warmup: true)

    assert_not PrCalculator.weight_pr?(warmup_set)
  end

  test 'weight_pr? returns false for nil reps' do
    # Previous workout
    create_workout_with_sets([ [ 80, 5 ] ], days_ago: 7)

    # Current workout with higher weight but nil reps
    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    nil_rep_set = we.exercise_sets.create!(weight_kg: 100, reps: nil, position: 1, is_warmup: false)

    assert_not PrCalculator.weight_pr?(nil_rep_set)
  end

  test 'PRs are scoped to specific machine' do
    other_machine = Machine.create!(name: 'Other Machine', gym: @gym, equipment_type: 'machine')

    # High weight on different machine
    workout1 = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: 7.days.ago,
      finished_at: 7.days.ago + 1.hour
    )
    block1 = workout1.workout_blocks.create!(position: 1, rest_seconds: 60)
    we1 = block1.workout_exercises.create!(
      exercise: @exercise,
      machine: other_machine,
      position: 1
    )
    we1.exercise_sets.create!(weight_kg: 150, reps: 5, position: 1, is_warmup: false)

    # Lower weight on target machine
    workout2 = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: 3.days.ago,
      finished_at: 3.days.ago + 1.hour
    )
    block2 = workout2.workout_blocks.create!(position: 1, rest_seconds: 60)
    we2 = block2.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    we2.exercise_sets.create!(weight_kg: 80, reps: 5, position: 1, is_warmup: false)

    # Current workout - should be PR because 85 > 80 (ignoring other machine's 150)
    workout3 = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block3 = workout3.workout_blocks.create!(position: 1, rest_seconds: 60)
    we3 = block3.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )
    set = we3.exercise_sets.create!(weight_kg: 85, reps: 5, position: 1, is_warmup: false)

    assert PrCalculator.weight_pr?(set)
  end

  test 'weight_pr? supports raw-only and equipped-only comparisons' do
    # Historical baseline: raw 100, equipped 120
    create_workout_with_sets(
      [
        { weight: 100, reps: 5, belt: false, knee_sleeves: false, wrist_wraps: false, straps: false },
        { weight: 120, reps: 3, belt: true }
      ],
      days_ago: 7
    )

    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )

    raw_set = we.exercise_sets.create!(weight_kg: 105, reps: 4, position: 1, is_warmup: false)
    equipped_set = we.exercise_sets.create!(weight_kg: 121, reps: 2, position: 2, is_warmup: false, belt: true)

    assert PrCalculator.weight_pr?(raw_set, equipped: false)
    assert_not PrCalculator.weight_pr?(raw_set, equipped: true)

    assert PrCalculator.weight_pr?(equipped_set, equipped: true)
    assert_not PrCalculator.weight_pr?(equipped_set, equipped: false)
  end

  test 'previous_best_weight supports raw and equipped filters' do
    create_workout_with_sets(
      [
        { weight: 90, reps: 6 },
        { weight: 110, reps: 3, belt: true }
      ],
      days_ago: 10
    )

    workout = Workout.create!(
      user: @user,
      gym: @gym,
      started_at: Time.current,
      finished_at: nil
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    we = block.workout_exercises.create!(
      exercise: @exercise,
      machine: @machine,
      position: 1
    )

    assert_equal 90, PrCalculator.previous_best_weight(we, equipped: false)
    assert_equal 110, PrCalculator.previous_best_weight(we, equipped: true)
    assert_equal 110, PrCalculator.previous_best_weight(we)
  end
end
