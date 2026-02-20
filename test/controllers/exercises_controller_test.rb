require 'test_helper'

class ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @exercise = exercises(:one)
    sign_in_as(@user)
  end

  test 'create persists form cues' do
    cues = "Brace hard\nDrive through heels"

    assert_difference('Exercise.count', 1) do
      post exercises_path, params: {
        exercise: {
          name: 'Cue Persistence Test',
          exercise_type: 'reps',
          has_weight: true,
          primary_muscle_group: 'quadriceps',
          form_cues: cues
        }
      }
    end

    created = Exercise.order(:id).last
    assert_equal cues, created.form_cues
  end

  test 'update persists form cues' do
    cues = "Shoulders down\nControlled eccentric"

    patch exercise_path(@exercise), params: {
      exercise: {
        form_cues: cues
      }
    }

    assert_redirected_to exercises_path
    @exercise.reload
    assert_equal cues, @exercise.form_cues
  end

  test 'create rejects missing primary muscle group' do
    assert_no_difference('Exercise.count') do
      post exercises_path, params: {
        exercise: {
          name: 'Missing Muscle Group',
          exercise_type: 'reps',
          has_weight: true,
          primary_muscle_group: '',
          form_cues: 'Test cue'
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
