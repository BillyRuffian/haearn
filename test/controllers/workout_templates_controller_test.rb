require 'test_helper'

class WorkoutTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workout = workouts(:one)
  end

  test 'create_from_workout creates template with non-warmup aggregated targets' do
    sign_in_as(@user)

    workout_exercise = workout_exercises(:one)
    ExerciseSet.create!(
      workout_exercise: workout_exercise,
      position: 2,
      is_warmup: false,
      weight_kg: 20,
      reps: 8
    )
    ExerciseSet.create!(
      workout_exercise: workout_exercise,
      position: 3,
      is_warmup: true,
      weight_kg: 999,
      reps: 1
    )

    assert_difference('WorkoutTemplate.count', 1) do
      assert_difference('TemplateBlock.count', 1) do
        assert_difference('TemplateExercise.count', 1) do
          post save_workout_as_template_path(@workout), params: {
            name: 'Copied Template',
            description: 'From test'
          }
        end
      end
    end

    template = WorkoutTemplate.order(:id).last
    template_exercise = template.template_blocks.first.template_exercises.first

    assert_redirected_to workout_template_path(template)
    assert_equal 2, template_exercise.target_sets
    assert_equal 5, template_exercise.target_reps
    assert_in_delta 15.0, template_exercise.target_weight_kg.to_f, 0.001
  end

  test 'create_from_workout requires authentication' do
    post save_workout_as_template_path(@workout), params: { name: 'Auth Required' }

    assert_redirected_to new_session_path
  end
end
