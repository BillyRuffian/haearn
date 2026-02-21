require 'rails_helper'
require 'ostruct'

RSpec.describe ApplicationHelper, type: :helper do
  before do
    Current.session = users(:one).sessions.create!
  end

  after do
    Current.reset
  end

  describe '#set_weight_display_for / #set_weight_unit_for' do
    it 'uses machine display unit when machine unit exists' do
      machine = Machine.new(display_unit: 'lbs')
      workout_exercise = OpenStruct.new(machine: machine)

      expect(helper.set_weight_display_for(45.36, workout_exercise)).to eq('100')
      expect(helper.set_weight_unit_for(workout_exercise)).to eq('lbs')
    end

    it 'falls back to user preferred unit when machine unit is absent' do
      workout_exercise = OpenStruct.new(machine: nil)

      expect(helper.set_weight_display_for(45.36, workout_exercise)).to eq('45.36')
      expect(helper.set_weight_unit_for(workout_exercise)).to eq('kg')
    end
  end
end
