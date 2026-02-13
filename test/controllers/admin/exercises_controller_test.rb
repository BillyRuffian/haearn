require 'test_helper'

class Admin::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @exercise = exercises(:one)
  end

  test 'admin can list exercises' do
    sign_in_as(@admin)
    get admin_exercises_path
    assert_response :success
  end

  test 'admin can show an exercise' do
    sign_in_as(@admin)
    get admin_exercise_path(@exercise)
    assert_response :success
  end

  test 'admin can view new exercise form' do
    sign_in_as(@admin)
    get new_admin_exercise_path
    assert_response :success
  end

  test 'admin can create a global exercise' do
    sign_in_as(@admin)
    assert_difference 'Exercise.count' do
      post admin_exercises_path, params: {
        exercise: { name: 'New Global Ex', exercise_type: 'reps', has_weight: true }
      }
    end
    exercise = Exercise.last
    assert_nil exercise.user_id
    assert_redirected_to admin_exercise_path(exercise)
  end

  test 'admin can update an exercise' do
    sign_in_as(@admin)
    patch admin_exercise_path(@exercise), params: { exercise: { name: 'Updated Name' } }
    assert_redirected_to admin_exercise_path(@exercise)
    assert_equal 'Updated Name', @exercise.reload.name
  end

  test 'admin can promote a user exercise' do
    sign_in_as(@admin)
    assert_not_nil @exercise.user_id
    post promote_admin_exercise_path(@exercise)
    assert_redirected_to admin_exercise_path(@exercise)
    assert_nil @exercise.reload.user_id
  end

  test 'admin can view review page' do
    sign_in_as(@admin)
    get review_admin_exercises_path
    assert_response :success
  end

  test 'admin can filter exercises by source' do
    sign_in_as(@admin)
    get admin_exercises_path, params: { scope_filter: 'global' }
    assert_response :success
  end

  test 'non-admin cannot access exercises admin' do
    sign_in_as(@user)
    get admin_exercises_path
    assert_redirected_to root_path
  end

  test 'admin can view merge page' do
    sign_in_as(@admin)
    get merge_admin_exercise_path(@exercise)
    assert_response :success
  end

  test 'admin can search on merge page' do
    sign_in_as(@admin)
    get merge_admin_exercise_path(@exercise), params: { search: 'Bench' }
    assert_response :success
  end

  test 'admin can merge duplicate into target' do
    sign_in_as(@admin)
    target = exercises(:bench_press)

    assert_difference 'Exercise.count', -1 do
      post merge_admin_exercise_path(@exercise), params: { target_id: target.id }
    end

    assert_redirected_to admin_exercise_path(target)
    assert_equal 0, WorkoutExercise.where(exercise_id: @exercise.id).count
  end

  test 'merge creates audit log entry' do
    sign_in_as(@admin)
    target = exercises(:bench_press)

    assert_difference 'AdminAuditLog.count' do
      post merge_admin_exercise_path(@exercise), params: { target_id: target.id }
    end

    log = AdminAuditLog.last
    assert_equal 'merge_exercise', log.action
  end

  test 'non-admin cannot merge exercises' do
    sign_in_as(@user)
    target = exercises(:bench_press)
    post merge_admin_exercise_path(@exercise), params: { target_id: target.id }
    assert_redirected_to root_path
  end
end
