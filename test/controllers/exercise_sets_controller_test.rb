require 'test_helper'

class ExerciseSetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    @workout = @user.workouts.create!(
      gym: gyms(:one),
      started_at: Time.current,
      finished_at: nil
    )
    @block = @workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    @workout_exercise = @block.workout_exercises.create!(
      exercise: exercises(:one),
      machine: machines(:one),
      position: 1
    )
  end

  test 'create persists set modifiers' do
    assert_difference('ExerciseSet.count', 1) do
      post workout_workout_exercise_exercise_sets_path(@workout, @workout_exercise), params: {
        exercise_set: {
          weight_value: 100,
          reps: 8,
          is_warmup: '0',
          is_amrap: '1',
          is_failed: '1',
          set_type: 'drop_set',
          belt: '1',
          straps: '1',
          rpe: '9.5',
          rir: '1'
        }
      }
    end

    set = @workout_exercise.exercise_sets.order(:id).last
    assert set.is_amrap?
    assert set.is_failed?
    assert_equal 'drop_set', set.set_type
    assert set.belt?
    assert set.straps?
    assert_equal 9.5, set.rpe.to_f
    assert_equal 1, set.rir
  end
end
