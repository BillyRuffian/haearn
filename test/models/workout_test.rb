# == Schema Information
#
# Table name: workouts
#
#  id          :integer          not null, primary key
#  finished_at :datetime
#  notes       :text
#  started_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  gym_id      :integer          not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_workouts_on_gym_id   (gym_id)
#  index_workouts_on_user_id  (user_id)
#
# Foreign Keys
#
#  gym_id   (gym_id => gyms.id)
#  user_id  (user_id => users.id)
#
require 'test_helper'

class WorkoutTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
