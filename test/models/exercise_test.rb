# == Schema Information
#
# Table name: exercises
#
#  id                   :integer          not null, primary key
#  description          :text
#  exercise_type        :string
#  form_cues            :text
#  has_weight           :boolean
#  name                 :string
#  primary_muscle_group :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :integer
#
# Indexes
#
#  index_exercises_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
require 'test_helper'

class ExerciseTest < ActiveSupport::TestCase
  setup do
    @exercise = exercises(:one)
  end

  # --- Form Cues ---

  test 'has_cues? returns false when form_cues blank' do
    @exercise.form_cues = nil
    assert_not @exercise.has_cues?

    @exercise.form_cues = ''
    assert_not @exercise.has_cues?
  end

  test 'has_cues? returns true when form_cues present' do
    @exercise.form_cues = "Drive through heels\nBrace core"
    assert @exercise.has_cues?
  end

  test 'cues_list splits by newline and strips whitespace' do
    @exercise.form_cues = "  Drive through heels  \n  Brace core  \n  Elbows at 45°  "
    list = @exercise.cues_list
    assert_equal 3, list.length
    assert_equal 'Drive through heels', list[0]
    assert_equal 'Brace core', list[1]
    assert_equal 'Elbows at 45°', list[2]
  end

  test 'cues_list rejects blank lines' do
    @exercise.form_cues = "Cue one\n\n\nCue two\n"
    list = @exercise.cues_list
    assert_equal 2, list.length
  end

  test 'cues_list returns empty array when nil' do
    @exercise.form_cues = nil
    assert_equal [], @exercise.cues_list
  end
end
