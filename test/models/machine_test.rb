# == Schema Information
#
# Table name: machines
#
#  id             :integer          not null, primary key
#  display_unit   :string
#  equipment_type :string
#  name           :string
#  notes          :text
#  weight_ratio   :decimal(, )
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  gym_id         :integer          not null
#
# Indexes
#
#  index_machines_on_gym_id  (gym_id)
#
# Foreign Keys
#
#  gym_id  (gym_id => gyms.id)
#
require 'test_helper'

class MachineTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
