require 'rails_helper'

RSpec.describe TrainingProgressionCalculator do
  def session(reps, weight: 37.5)
    { sets: reps.map { |value| { weight_kg: weight, reps: value, set_type: 'normal' } } }
  end

  def calculate(current, history, target: nil, weighted_reps: true)
    described_class.new(current: current, history: history, target: target, weighted_reps: weighted_reps).call
  end

  it 'recognises rep progression before a 4x10 target is achieved' do
    result = calculate(session([ 10, 10, 10, 9 ]), [ session([ 10, 10, 8, 9 ]) ],
      target: { sets: 4, reps: 10, weight_kg: 37.5 })
    expect(result).to include(working_sets: 4, load_volume_kg_reps: 1462.5, previous_load_volume_kg_reps: 1387.5,
      volume_change_percent: 5.4, estimated_1rm_kg: 50.0, estimated_1rm_change_percent: 0.0,
      recent_trend: 'progressing', programmed_rep_target_reached: false, consecutive_sessions_at_current_load: 2)
    expect(calculate(session([ 10 ] * 4), [], target: { sets: 4, reps: 10 })[:programmed_rep_target_reached]).to be(true)
  end

  it 'does not label one weaker session a plateau or meaningful regression' do
    expect(calculate(session([ 8 ]), [ session([ 10 ]) ])).to include(recent_trend: 'stable', recent_performance_regression: nil)
    expect(calculate(session([ 10 ]), [ session([ 10 ]) ])[:recent_trend]).to eq('stable')
    expect(calculate(session([ 10 ]), [ session([ 10 ]), session([ 10 ]), session([ 10 ]) ])[:recent_trend]).to eq('possible_plateau')
    expect(calculate(session([ 6 ]), [ session([ 8 ]), session([ 10 ]) ])[:recent_performance_regression]).to be(true)
  end

  it 'leaves missing history, zero baselines, high-rep e1RM and unsupported volume unknown' do
    expect(calculate(session([ 12 ]), [])).to include(recent_trend: 'insufficient_data', estimated_1rm_kg: nil,
      previous_load_volume_kg_reps: nil, volume_change_percent: nil, programmed_rep_target_reached: nil)
    expect(calculate(session([ 10 ]), [ session([ 10 ], weight: 0) ])[:volume_change_percent]).to be_nil
    expect(calculate(session([ 10 ]), [], weighted_reps: false)[:load_volume_kg_reps]).to be_nil
    expect(calculate({ sets: [] }, [])[:estimated_1rm_kg]).to be_nil
  end
end
