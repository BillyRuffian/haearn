require 'rails_helper'

RSpec.describe WorkoutAnalysesHelper, type: :helper do
  it 'converts normalized recommendation loads back through the stored machine ratio and unit' do
    feedback = { 'next_session' => { 'weight_kg' => 22.6796185 } }
    context = { 'machine_id' => 1, 'machine_weight_ratio' => 0.5, 'display_unit' => 'lbs' }
    expect(helper.coaching_target_weight(feedback, context)).to eq('100 lbs')
    context['machine_id'] = nil
    expect(helper.coaching_target_weight(feedback, context)).to eq('50 lbs')
    expect(helper.coaching_target_weight({ 'next_session' => { 'weight_kg' => nil } }, context)).to be_nil
  end
end
