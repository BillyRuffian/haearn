require 'test_helper'

class ExercisePolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @user_exercise = exercises(:one)
    @global_exercise = Exercise.create!(
      name: 'Global Test',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest',
      user: nil
    )
  end

  test 'anyone can index exercises' do
    assert ExercisePolicy.new(@user, Exercise).index?
    assert ExercisePolicy.new(@admin, Exercise).index?
  end

  test 'anyone can see global exercises' do
    assert ExercisePolicy.new(@user, @global_exercise).show?
  end

  test 'user can see own exercises' do
    assert ExercisePolicy.new(@user, @user_exercise).show?
  end

  test 'admin can promote user exercises' do
    assert ExercisePolicy.new(@admin, @user_exercise).promote?
  end

  test 'admin cannot promote already global exercises' do
    assert_not ExercisePolicy.new(@admin, @global_exercise).promote?
  end

  test 'regular user cannot promote exercises' do
    assert_not ExercisePolicy.new(@user, @user_exercise).promote?
  end

  test 'admin can review exercises' do
    assert ExercisePolicy.new(@admin, Exercise).review?
  end

  test 'regular user cannot review exercises' do
    assert_not ExercisePolicy.new(@user, Exercise).review?
  end

  test 'scope returns all for admin' do
    scope = ExercisePolicy::Scope.new(@admin, Exercise).resolve
    assert_equal Exercise.count, scope.count
  end
end
