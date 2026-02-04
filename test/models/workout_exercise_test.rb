# == Schema Information
#
# Table name: workout_exercises
#
#  id               :integer          not null, primary key
#  persistent_notes :text
#  position         :integer
#  session_notes    :text
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
  # test "the truth" do
  #   assert true
  # end
end
