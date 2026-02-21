require 'test_helper'
require 'ostruct'

class ApplicationHelperTest < ActionView::TestCase
  setup do
    Current.session = users(:one).sessions.create!
  end

  teardown do
    Current.reset
  end

  test 'input_weight_unit_for prefers machine display unit when present' do
    machine = Machine.new(display_unit: 'lbs')
    workout_exercise = OpenStruct.new(machine: machine)

    assert_equal 'lbs', input_weight_unit_for(workout_exercise)
  end

  test 'input_weight_unit_for falls back to user preferred unit' do
    workout_exercise = OpenStruct.new(machine: nil)

    assert_equal 'kg', input_weight_unit_for(workout_exercise)
  end

  test 'input_weight_value_for converts stored kg to machine display unit' do
    machine = Machine.new(display_unit: 'lbs')
    workout_exercise = OpenStruct.new(machine: machine)

    assert_equal '100', input_weight_value_for(45.36, workout_exercise)
  end

  test 'input_weight_value_for converts stored kg to user unit when no machine unit' do
    workout_exercise = OpenStruct.new(machine: nil)

    assert_equal '45.36', input_weight_value_for(45.36, workout_exercise)
  end

  test 'set_weight_display_for uses machine display conversion when machine unit exists' do
    machine = Machine.new(display_unit: 'lbs')
    workout_exercise = OpenStruct.new(machine: machine)

    assert_equal '100', set_weight_display_for(45.36, workout_exercise)
    assert_equal 'lbs', set_weight_unit_for(workout_exercise)
  end

  test 'set_weight_display_for falls back to user preferred unit without machine unit' do
    workout_exercise = OpenStruct.new(machine: nil)

    assert_equal '45.36', set_weight_display_for(45.36, workout_exercise)
    assert_equal 'kg', set_weight_unit_for(workout_exercise)
  end
end
