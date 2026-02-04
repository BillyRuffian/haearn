# == Schema Information
#
# Table name: exercises
#
#  id                   :integer          not null, primary key
#  description          :text
#  exercise_type        :string
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
  # test "the truth" do
  #   assert true
  # end
end
