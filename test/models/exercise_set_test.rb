# == Schema Information
#
# Table name: exercise_sets
#
#  id                  :integer          not null, primary key
#  completed_at        :datetime
#  distance_meters     :decimal(, )
#  duration_seconds    :integer
#  is_warmup           :boolean
#  position            :integer
#  reps                :integer
#  rir                 :integer
#  rpe                 :decimal(, )
#  weight_kg           :decimal(, )
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  workout_exercise_id :integer          not null
#
# Indexes
#
#  index_exercise_sets_on_workout_exercise_id  (workout_exercise_id)
#
# Foreign Keys
#
#  workout_exercise_id  (workout_exercise_id => workout_exercises.id)
#
require 'test_helper'

class ExerciseSetTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
