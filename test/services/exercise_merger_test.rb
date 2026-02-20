require 'test_helper'

class ExerciseMergerTest < ActiveSupport::TestCase
  setup do
    @target = exercises(:bench_press)
    @duplicate = exercises(:one) # user-created "Custom Bench Press"
  end

  test 'merges duplicate workout_exercises into target' do
    # exercise :one has workout_exercises referencing it (from fixtures)
    original_count = WorkoutExercise.where(exercise_id: @duplicate.id).count
    assert original_count > 0, 'Duplicate should have workout uses for this test'

    result = ExerciseMerger.call(target: @target, duplicate: @duplicate)

    assert result.success?
    assert_equal 0, WorkoutExercise.where(exercise_id: @duplicate.id).count
    assert Exercise.where(id: @duplicate.id).none?, 'Duplicate should be deleted'
  end

  test 'deletes the duplicate exercise' do
    assert_difference 'Exercise.count', -1 do
      ExerciseMerger.call(target: @target, duplicate: @duplicate)
    end
  end

  test 'returns descriptive success message' do
    result = ExerciseMerger.call(target: @target, duplicate: @duplicate)

    assert result.success?
    assert_includes result.message, @duplicate.name
    assert_includes result.message, @target.name
    assert_includes result.message, 'Reassigned'
  end

  test 'fails when target and duplicate are the same' do
    result = ExerciseMerger.call(target: @target, duplicate: @target)

    refute result.success?
    assert_includes result.message, 'different'
  end

  test 'works when duplicate has no workout uses' do
    # Create a fresh exercise with no associations
    fresh = Exercise.create!(
      name: 'Orphan Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    result = ExerciseMerger.call(target: @target, duplicate: fresh)

    assert result.success?
    assert_includes result.message, '0 workout uses'
    assert Exercise.where(id: fresh.id).none?
  end
end
