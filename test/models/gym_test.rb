# == Schema Information
#
# Table name: gyms
#
#  id         :integer          not null, primary key
#  location   :string
#  name       :string
#  notes      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_gyms_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
require 'test_helper'

class GymTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
