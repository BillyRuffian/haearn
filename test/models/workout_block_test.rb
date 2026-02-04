# == Schema Information
#
# Table name: workout_blocks
#
#  id           :integer          not null, primary key
#  position     :integer
#  rest_seconds :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  workout_id   :integer          not null
#
# Indexes
#
#  index_workout_blocks_on_workout_id  (workout_id)
#
# Foreign Keys
#
#  workout_id  (workout_id => workouts.id)
#
require 'test_helper'

class WorkoutBlockTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
