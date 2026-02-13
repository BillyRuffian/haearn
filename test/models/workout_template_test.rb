# == Schema Information
#
# Table name: workout_templates
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  pinned      :boolean          default(FALSE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_workout_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
require 'test_helper'

class WorkoutTemplateTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
