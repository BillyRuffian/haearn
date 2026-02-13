# == Schema Information
#
# Table name: workout_exercises
#
#  id               :integer          not null, primary key
#  bar_type         :string
#  grip_width       :string
#  incline_angle    :integer
#  persistent_notes :text
#  position         :integer
#  session_notes    :text
#  stance           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  exercise_id      :integer          not null
#  machine_id       :integer          not null
#  workout_block_id :integer          not null
#
# Indexes
#
#  index_workout_exercises_on_exercise_id       (exercise_id)
#  index_workout_exercises_on_machine_id        (machine_id)
#  index_workout_exercises_on_workout_block_id  (workout_block_id)
#
# Foreign Keys
#
#  exercise_id       (exercise_id => exercises.id)
#  machine_id        (machine_id => machines.id)
#  workout_block_id  (workout_block_id => workout_blocks.id)
#
require 'test_helper'

class WorkoutExerciseTest < ActiveSupport::TestCase
  setup do
    @we = workout_exercises(:one)
  end

  # --- Grip Width ---

  test 'valid grip widths accepted' do
    WorkoutExercise::GRIP_WIDTHS.each do |gw|
      @we.grip_width = gw
      assert @we.valid?, "Expected grip_width '#{gw}' to be valid"
    end
  end

  test 'invalid grip width rejected' do
    @we.grip_width = 'super_wide'
    assert_not @we.valid?
  end

  test 'nil grip width accepted' do
    @we.grip_width = nil
    assert @we.valid?
  end

  # --- Stance ---

  test 'valid stances accepted' do
    WorkoutExercise::STANCES.each do |s|
      @we.stance = s
      assert @we.valid?, "Expected stance '#{s}' to be valid"
    end
  end

  test 'invalid stance rejected' do
    @we.stance = 'flamingo'
    assert_not @we.valid?
  end

  test 'nil stance accepted' do
    @we.stance = nil
    assert @we.valid?
  end

  # --- Bar Type ---

  test 'valid bar types accepted' do
    WorkoutExercise::BAR_TYPES.each do |bt|
      @we.bar_type = bt
      assert @we.valid?, "Expected bar_type '#{bt}' to be valid"
    end
  end

  test 'invalid bar type rejected' do
    @we.bar_type = 'pool_noodle'
    assert_not @we.valid?
  end

  test 'nil bar type accepted' do
    @we.bar_type = nil
    assert @we.valid?
  end

  # --- Incline Angle ---

  test 'incline_angle accepts valid range' do
    @we.incline_angle = -90
    assert @we.valid?
    @we.incline_angle = 0
    assert @we.valid?
    @we.incline_angle = 90
    assert @we.valid?
  end

  test 'incline_angle rejects out of range' do
    @we.incline_angle = -91
    assert_not @we.valid?
    @we.incline_angle = 91
    assert_not @we.valid?
  end

  test 'nil incline_angle accepted' do
    @we.incline_angle = nil
    assert @we.valid?
  end

  # --- Variation Helpers ---

  test 'has_variations? false when no modifiers set' do
    @we.grip_width = nil
    @we.stance = nil
    @we.incline_angle = nil
    @we.bar_type = nil
    assert_not @we.has_variations?
  end

  test 'has_variations? true with grip_width' do
    @we.grip_width = 'wide'
    assert @we.has_variations?
  end

  test 'has_variations? true with incline_angle' do
    @we.incline_angle = 30
    assert @we.has_variations?
  end

  test 'variation_summary joins labels' do
    @we.grip_width = 'wide'
    @we.stance = 'sumo'
    summary = @we.variation_summary
    assert_includes summary, 'Wide'
    assert_includes summary, 'Sumo'
  end

  test 'variation_summary includes angle' do
    @we.incline_angle = 45
    assert_includes @we.variation_summary, '45°'
  end

  test 'grip_width_label returns titleized label' do
    @we.grip_width = 'close'
    assert_equal 'Close Grip', @we.grip_width_label
  end

  test 'stance_label returns titleized label' do
    @we.stance = 'sumo'
    assert_equal 'Sumo', @we.stance_label
  end

  test 'bar_type_label returns human-readable label' do
    @we.bar_type = 'ez_curl'
    assert_equal 'EZ-Curl', @we.bar_type_label
  end
end
