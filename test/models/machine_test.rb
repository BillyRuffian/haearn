# == Schema Information
#
# Table name: machines
#
#  id             :integer          not null, primary key
#  display_unit   :string
#  equipment_type :string
#  handle_setting :string
#  name           :string
#  notes          :text
#  pin_setting    :string
#  seat_setting   :string
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
  test 'setup_memory? true when any setup field is present' do
    machine = Machine.new(
      name: 'Leg Press',
      gym: gyms(:one),
      equipment_type: 'machine',
      seat_setting: '4'
    )

    assert machine.setup_memory?
  end

  test 'setup_memory_summary joins configured settings in display order' do
    machine = Machine.new(
      name: 'Cable Row',
      gym: gyms(:one),
      equipment_type: 'cables',
      seat_setting: '3',
      pin_setting: '8',
      handle_setting: 'Neutral'
    )

    assert_equal 'Seat 3 · Pin 8 · Handle Neutral', machine.setup_memory_summary
  end
end
